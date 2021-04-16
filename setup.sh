#!/bin/bash

##[ Imports ]####################

source "$(dirname $0)/utils.sh"

##[ Functions ]##################

function setuptck {

    echo "${CXF_VERSION?Specify the CXF version}"
    echo "${GF_VERSION?Specify the GlassFish version}"
    
    ##
    ## Check to see if any previous setup is still good.
    ## If the build of CXF we used is the same, we don't
    ## need to run setup again
    ##
    FILE=/tmp/latest.jar
    copydep "org.apache.cxf:cxf-rt-frontend-jaxrs:${CXF_VERSION}:jar" "/tmp/latest.jar"
    sha512sum -c setup.sha && {
	echo "Setup is current"
	return
    }

    ##
    ## It's not current, so let's rebuild everything
    ## and create a new setup.sha file at the end
    ## 
    
    export ANT_OPTS="-Djavax.xml.accessExternalSchema=all"
    GF="glassfish-$GF_VERSION"
    GF_URL="https://repo1.maven.org/maven2/org/glassfish/main/distributions/glassfish/$GF_VERSION/$GF.zip"
    GF_HOME="$WORKSPACE/$GF_DIR/glassfish"


    stage 'Download JakartaEE TCK'
    {
	[ -d jakartaee-tck ] && (
	    cd jakartaee-tck && git clean -fd
	) || {
	    git clone git@github.com:eclipse-ee4j/jakartaee-tck.git -b 8.0.0
	}
    } || fail


    stage "Download Glassfish $GF_VERSION"
    {
	## Download the RI if we have not
	[ -f "$GF.zip" ] || (
	    echo "Downloading $GF.zip"
	    curl "$GF_URL" > "$GF.zip" || fail
	)
	
	echo "Downloaded $GF.zip"
	
	## Delete and re-extract the RI
	[ -d "$GF_DIR" ] && rm -rf "$GF_DIR"
     	echo "Extracting to $GF_DIR"
	unzip "$GF.zip" || fail

	 echo "Extracted $GF"
    } || fail


    stage "Download Ant"
    [ -d "$ANT_HOME" ] || {

	## Download ant if we have not
	[ -f "$WORKSPACE/apache-ant-1.10.9-bin.zip" ] || (
	    echo "Downloading ant"
	    cd "$WORKSPACE" &&
		curl -s -O https://archive.apache.org/dist/ant/binaries/apache-ant-1.10.9-bin.zip
	)

	echo "Downloaded ant"
	
	## Extract ant into TCK if we have not
	[ -d "$WORKSPACE/apache-ant-1.10.9" ] || (
	    echo "Extracting ant"
	    cd "$WORKSPACE" &&
		unzip "apache-ant-1.10.9-bin.zip"
	)

	echo "Extracted ant"

	export ANT_HOME="$WORKSPACE/apache-ant-1.10.9"
    }

    stage "Download Apache CXF bits"
    {
	copydep "org.apache.cxf:cxf-core:${CXF_VERSION}:jar" "$GF_HOME/lib"
	copydep "org.apache.cxf:cxf-rt-frontend-jaxrs:${CXF_VERSION}:jar" "$GF_HOME/lib"
	copydep "org.apache.cxf:cxf-rt-rs-client:${CXF_VERSION}:jar" "$GF_HOME/lib"
	copydep "org.apache.cxf:cxf-rt-rs-sse:${CXF_VERSION}:jar" "$GF_HOME/lib"
	copydep "org.apache.cxf:cxf-rt-transports-http:${CXF_VERSION}:jar" "$GF_HOME/lib"
	copydep "com.fasterxml.woodstox:woodstox-core:5.2.1:jar" "$GF_HOME/lib"
    } || fail

    
    stage 'Prepare JAX-RS TCK build configuration'
    {
	curl -O https://raw.githubusercontent.com/apache/cxf/master/tck/ts.jte.template
	perl -i -pe "s,^(web.home=.*),version=$CXF_VERSION\nGF_HOME=$GF_HOME\n\$1," ts.jte.template
	cp jakartaee-tck/bin/xml/impl/glassfish/jersey.xml jakartaee-tck/bin/xml/impl/glassfish/cxf.xml
    } || fail


    stage 'Build JAX-RS TCK'
    {
	export WORKSPACE="${PWD}"
	export TS_HOME=${WORKSPACE}/jakartaee-tck
	export javaee_home=${WORKSPACE}/glassfish5
	export GF_HOME=${WORKSPACE}/glassfish5/glassfish
	export AS_JAVA=$JAVA_HOME
	export deliverabledir=jaxrs
	
	cp -vr ts.jte.template jakartaee-tck/install/jaxrs/bin/ts.jte

	(cd "${TS_HOME}/install/${deliverabledir}/bin" &&
	     ant build.all &&
	     ant update.jaxrs.wars
	)
	
	(cd "${TS_HOME}/release/tools/" &&
	     ant jaxrs
	)
    } || fail


    stage 'Setup JAX-RS TCK'
    {
	TS_HOME="${WORKSPACE}/restful-ws-tck"
	cp -r jakartaee-tck/release/JAXRS_BUILD/latest/restful-ws-tck "$TS_HOME"
	cp -vr ts.jte.template "${TS_HOME}/bin/ts.jte"
	
    } || fail

    stage 'Record CXF sha512'
    {
	sha512sum /tmp/latest.jar > setup.sha
    }
}

