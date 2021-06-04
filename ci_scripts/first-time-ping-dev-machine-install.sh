#!/usr/bin/env sh
_osID=$( awk '$0~/^ID=/ {split($1,id,"="); gsub(/"/,"",id[2]); print id[2];}' </etc/os-release 2>/dev/null )
_osArch=$( uname -m )
_user=$( whoami )
mkdir ~/projects
case "${_osID}" in
    ubuntu)
        case "${_osArch}" in
            aarch64)_arch="arm64" ;;
            x84_64)_arch="amd64" ;;
            *) echo "Unsupported platform" && exit 99 ;;
        esac
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        sudo echo "deb [arch=${_arch} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get -y update
        sudo apt-get -y install apt-transport-https ca-certificates curl gnupg lsb-release git jq docker-ce=5:19.03.3~3-0~ubuntu-bionic docker-ce-cli containerd.io python3-pip unzip
        # DO NOT INSTALL docker-compose with apt-get, it is old and has issue with buildkit
    ;;
    amzn|centos)
        sudo yum -y update
        sudo yum groupinstall -y "Development Tools"
        yes | sudo amazon-linux-extras install docker
        sudo yum -y install git jq python3 python3-pip python3-devel libxml2-devel libxslt-devel
        sudo service docker start
    ;;
esac
sudo usermod -a -G docker ${_user}
case "${_osArch}" in
    aarch64)
        _vanityArch="arm64"
        _tmpDir=$( mktemp -d )
        wget -O ${_tmpDir}/compose.tgz https://github.com/docker/compose/archive/1.29.0.tar.gz
        tar -C ${_tmpDir} -xzf ${_tmpDir}/compose.tgz
        sudo python3 -m pip install -U pip
        ( cd ${_tmpDir}/compose-* && python3 -m pip install -IU docker-compose )
        test ${?} -eq 0 && rm -rf ${_tmpDir}
        ;;
    x86_64)
        _vanityArch="amd64"
        sudo curl -L "https://github.com/docker/compose/releases/download/1.28.6/docker-compose-$(uname -s)-${_osArch}" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        ;;
esac
curl "https://awscli.amazonaws.com/awscli-exe-linux-${_osArch}.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
wget -O /tmp/saml2aws.tgz https://github.com/Versent/saml2aws/releases/download/v2.29.0/saml2aws_2.29.0_linux_${_vanityArch}.tar.gz
sudo tar -C /usr/local/bin -xzf /tmp/saml2aws.tgz  
~/.local/bin/docker-compose --version
cat <<END >> ~/.bashrc
if test -f ~/.pingidentity/devops
then
    set -o allexport
    . ~/.pingidentity/devops
    set +o allexport
fi
# add the locally built docker-compose binary to the path
export PATH=~/.local/bin:${PATH}
export AWS_REGION=us-west-2
END
cat<<END
Don't forget to export the AWS account ID 
export AWS_ACCOUNT=*********

Log out, back in and run:
  saml2aws configure
  saml2aws login
  aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
END
exit 0