#!/bin/bash
#
# Install script for dependencies for the Beluga Project within docker container
#
# The script will install the following dependencies needed
# to run and build the Beluga Project.
#
# Dependencies: needed for building the Beluga Project:
# * Java (at least Java 14, script will install Java 17)
# * Maven
# * Nodejs
# * Npm
# * Angular

set -e # fail on error

# globals - if necessary adjust these values!
javaInstalled=no
installJava17=yes

mavenInstalled=no
installMaven=yes
installMavenVersion=3.8.6

postgresInstalled=no

nodejsInstalled=no
installNodejs=yes
installNodejsVersion=16.x

# function installs Java 17 from adoptium in /opt/jdk/
function install_java_17() {
    local filename=jdk17.tar.gz
    local jdk_directory=/opt/jdk
    local armSystemJavaUrl="https://api.adoptium.net/v3/binary/latest/17/ga/linux/arm/jdk/hotspot/normal/eclipse?project=jdk"
    local x64SystemJavaUrl="https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse?project=jdk"

    # detect 32- or 64-bit system to set the right java download url
    cpuOpMode=$(getconf LONG_BIT)
    if [ "$cpuOpMode" -eq "64" ]; then
        echo "system is 64-bit. Download link for java x64 will be used ..."

        # download java 17 jdk for x64 and rename file to "jdk17.tar.gz"
        echo download java 17 jdk ...
        wget -O $filename $x64SystemJavaUrl

    elif [ "$cpuOpMode" -eq "32" ]; then
        echo "system is 32-bit. Download link for java arm will be used ..."

        # download java 17 jdk for arm and rename file to "jdk17.tar.gz"
        echo download java 17 jdk ...
        wget -O $filename $armSystemJavaUrl
    else
        echo "system could not be detected. Script will not proceed" >&2
        exit
    fi

    # extract first level directory name
    local firstLvlDirName=$(tar -tzf "$filename" | head -1 | cut -f1 -d"/")

    # create jdk directory
    echo create jdk directory ...
    mkdir $jdk_directory

    # uncompress tar, change to your file name
    echo uncompress downloaded file ...
    tar -zxf $filename -C $jdk_directory

    # update alternatives so the command java and javac point to the new jdk
    echo update alternatives so the command java and javac point to the new jdk ...
    update-alternatives --install /usr/bin/java java $jdk_directory/$firstLvlDirName/bin/java 100
    update-alternatives --install /usr/bin/javac javac $jdk_directory/$firstLvlDirName/bin/javac 100

    # check if java and javac command are pointing to jdk directory
    echo check if java command is pointing to jdk directory $jdk_directory/$firstLvlDirName/ ...
    update-alternatives --display java
    update-alternatives --display javac

    # check if java 17 is running
    echo check java version ...
    if command -v java &>/dev/null; then
        javaInstalled=yes
        echo "java 17 installed successfully"
    else
        echo "java 17 is not installed. Script will not proceed" >&2
        exit
    fi
}

function install_maven() {
    local filename=apache-maven-$installMavenVersion-bin.tar.gz
    local maven_directory=/opt/maven

    # download maven and rename file
    echo download maven $installMavenVersion ...
    wget -O $filename "https://dlcdn.apache.org/maven/maven-3/"$installMavenVersion"/binaries/apache-maven-"$installMavenVersion"-bin.tar.gz"

    # delete maven directory if it exists
    if [ -d "$maven_directory" ]; then
        echo "maven directory $maven_directory already exists. Script will delete maven directory"
        rm -r $maven_directory
    else
        echo "maven directory $maven_directory does not exist"
    fi

    # create directory
    echo create directory for maven ...
    mkdir $maven_directory

    # uncompress, change to your file name
    echo uncompress downloaded file ...
    tar -zxf $filename -C $maven_directory

    # Add the bin directory to your PATH, reload bashrc and create symbolic link under /usr/bin
    echo setting path ...
    echo "export PATH=/opt/maven/apache-maven-"$installMavenVersion"/bin:$PATH" >>~/.bashrc
    source ~/.bashrc
    ln -s -f /opt/maven/apache-maven-$installMavenVersion/bin/mvn /usr/bin/mvn

    # check if maven is running
    echo check maven version ...
    if command -v mvn &>/dev/null; then
        local currentMavenVersion=$(mvn -version | sed -Ee 's/Apache Maven ([0-9.]+).*/\1/;q')
        if [[ "$currentMavenVersion" == "$installMavenVersion" ]]; then
            echo "maven $installMavenVersion installed successfully"
            mavenInstalled=yes
        else
            echo maven $currentMavenVersion is installed. Script will not proceed >&2
            exit
        fi
    else
        echo "maven $installMavenVersion is not installed. Script will not proceed" >&2
        exit
    fi
}

# function installs nodejs 16.x (including npm) from NodeSource,
# because the version in the official repositories is too old
function install_nodejs() {
    local filename=nodesource_setup.sh

    # Install new PPA maintained by NodeSource to get access to newer nodejs version
    # than from the official Ubuntu repositories. Retrieve the installation script with
    wget -O $filename "https://deb.nodesource.com/setup_16.x"

    # Install nodejs (including npm) without asking for user input
    bash nodesource_setup.sh
    apt install nodejs --assume-yes

    # Check if nodejs is installed
    if command -v node &>/dev/null; then
        local currentNodeVersion=$(node --version | sed -Ee 's/v([0-9.]+).*/\1/;q')
        echo "nodejs $currentNodeVersion installed successfully"
        nodejsInstalled=yes
    else
        echo "nodejs is not installed. Script will not proceed" >&2
        exit
    fi

    # Check if npm is installed
    if command -v npm &>/dev/null; then
        local currentNpmVersion=$(npm --version)
        echo "npm $currentNpmVersion installed successfully"
        npmInstalled=yes
    else
        echo "npm is not installed. Script will not proceed" >&2
        exit
    fi
}

function install_angular() {
    # Install angular
    npm install -g @angular/cli
}

function main() {
    echo "### Starting install script for the Beluga Project ###"

    echo "## --------------- Install Java 17  --------------- ##"

    # Check if java is already installed
    if command -v java &>/dev/null; then
        javaInstalled=yes
    fi

    # Install java if it is not installed or version is lower than 17
    if [[ $javaInstalled == yes ]]; then
        echo "java is already installed"

        # Check java version is greater than 17
        echo checking java version is greater than 17 ...
        local javaVersion=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')

        if [[ "$javaVersion" > "17" ]]; then
            echo java $javaVersion '('equal or higher than 17')' is already installed. Nothing to do here ...
            installJava17=no
        else
            echo java $javaVersion is installed
        fi
    fi

    if [[ $installJava17 == yes ]] || [[ $javaInstalled == no ]]; then
        echo java is not installed or version is lower than 17. The script will install java 17
        # install java 17
        install_java_17
    fi

    echo "## ------------------------------------------------ ##"

    echo "## ------------- Install Maven $installMavenVersion ------------- ##"

    # Check if maven is already installed
    if command -v mvn &>/dev/null; then
        mavenInstalled=yes
    fi

    # Install maven if it is not installed or version is lower than installMavenVersion
    if [[ $mavenInstalled == yes ]]; then
        echo "maven is already installed"

        # Check maven version is greater than installMavenVersion
        echo checking maven version is greater than $installMavenVersion ...
        currentMavenVersion=$(mvn -version | sed -Ee 's/Apache Maven ([0-9.]+).*/\1/;q')

        # Sorting the currentMavenVersion and the installMavenVersion and select the lower one
        local lowerMavenVersion=$(printf ''$currentMavenVersion'\n'$installMavenVersion'\n' | sort -V | head -n 1)

        if [[ "$lowerMavenVersion" == "$installMavenVersion" ]]; then
            echo maven version $currentMavenVersion is already installed '('or higher than $installMavenVersion')'. Nothing to do here ...
            installMaven=no
        else
            echo maven $currentMavenVersion is installed
        fi
    fi

    if [[ $installMaven == yes ]] || [[ $mavenInstalled == no ]]; then
        echo maven is not installed or version is lower than $installMavenVersion. The script will install maven $installMavenVersion and will delete the current directory $maven_directory if necessary
        # install maven
        install_maven
    fi

    echo "## ------------------------------------------------ ##"

    echo "## ------ Install Nodejs 16.x (including npm) ----- ##"

    # Check if nodejs is already installed
    if command -v node &>/dev/null; then
        nodejsInstalled=yes
    fi

    # Check if npm is already installed
    if command -v npm &>/dev/null; then
        npmInstalled=yes
    fi

    # Install nodejs if it is not installed or version is lower than 16.x
    if [[ $nodejsInstalled == yes ]]; then
        echo "nodejs is already installed"

        # Check nodejs version is greater than 16.x
        echo checking nodejs version is greater than $installNodejsVersion ...
        local currentNodejsVersion=$(node --version | sed -Ee 's/v([0-9.]+).*/\1/;q')

        # Sorting the currentNodeVersion and the installNodeVersion and select the lower one
        lowerNodejsVersion=$(printf ''$currentNodejsVersion'\n'$installNodejsVersion'\n' | sort -V | head -n 1)

        if [[ "$lowerNodejsVersion" == "$installNodejsVersion" ]]; then
            echo nodejs version $currentNodeVersion is installed '('higher than $installNodejsVersion')'. Nothing to do here ...
            installNodejs=no
        else
            echo nodejs $currentNodejsVersion is installed
        fi
    fi

    if [[ $installNodejs == yes ]] || [[ $nodejsInstalled == no ]]; then
        echo nodejs is not installed or version is lower than "$installNodejsVersion". The script will install nodejs "$installNodejsVersion" including npm
        # install nodejs 16.x
        install_nodejs
    fi

    echo "## ------------------------------------------------ ##"

    echo "## ---------------- Install Angular --------------- ##"

    if [[ $nodejsInstalled == yes ]] && [[ $npmInstalled == yes ]]; then
        echo the script will install angular
        # install angular
        install_angular
    fi

    echo "## --------------------- END ---------------------- ##"
}

# run main function
main
