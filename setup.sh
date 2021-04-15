#!/bin/bash

##[ Imports ]####################

source "$(dirname $0)/utility.sh"

##[ Functions ]##################

function setup {

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
    RI="glassfish-$RI_VERSION"
    RI_URL="https://repo1.maven.org/maven2/org/glassfish/main/distributions/glassfish/$RI_VERSION/$RI.zip"
    GF_HOME="$WORKSPACE/$RI_DIR/glassfish"


    stage 'Download JakartaEE TCK'
    {
	[ -d jakartaee-tck ] && (
	    cd jakartaee-tck && git clean -fd
	) || {
	    git clone git@github.com:eclipse-ee4j/jakartaee-tck.git -b 8.0.0
	}
    } || fail


    stage "Download Glassfish $RI_VERSION"
    {
	## Download the RI if we have not
	[ -f "$RI.zip" ] || (
	    echo "Downloading $RI.zip" curl "$RI_URL" > "$RI.zip"
	)
	
	echo "Downloaded $RI.zip"
	
	## Delete and re-extract the RI
	[ -d "$RI_DIR" ] && rm -rf "$RI_DIR"
     	echo "Extracting to $RI_DIR"
	unzip "$RI.zip"

	 echo "Extracted $RI"
    } || fail


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

