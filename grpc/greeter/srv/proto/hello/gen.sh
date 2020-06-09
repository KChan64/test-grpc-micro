#!/bin/bash

function printHelp() { 
	echo "Usage: -m -g -f test.proto" 1>&2;
	echo "-h help"
	echo "-f file path"
	echo "-i import third-party googleapis"
	echo "-m create micro"
	echo "-g create grpc-gateway"
	exit 1; 
}

function installGateway(){
	set GO111MODULE=on
	go get -u -v "github.com/golang/protobuf"
	go get -u -v "github.com/grpc-ecosystem/grpc-gateway"
	go install \
	    "github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway" \
	    "github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger" \
	    "github.com/golang/protobuf/protoc-gen-go"
}

function installMirco(){
	set GO111MODULE=on
	go get -u -v "github.com/micro/go-micro"
	go get -u -v "github.com/micro/micro"

}

function checkEnv(){
	if [ ! -d "$GOPATH/src/github.com/googleapis/googleapis" ]; then
    	echo "googleapis not exists."
	fi
	if [ ! -d "$GOPATH/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis" ]; then
    	echo "third_party/googleapis not exists."
	fi
	if [ ! -d "$GOPATH/src/github.com/grpc-ecosystem/grpc-gateway" ]; then
    	echo "grpc-gateway not exists."
	fi
	if [ ! -d "$GOPATH/src/github.com/micro/go-micro" ]; then
    	echo "go-micro not exists."
	fi
	if [ ! -d "$GOPATH/src/github.com/golang/protobuf" ]; then
    	echo "protobuf not exists."
	fi
	if [ ! -d "$GOROOT/src/google.golang.org/grpc" ]; then
    	echo "grpc not exists."
	fi
}

function CreateProtofile(){
	# pb
	# --go_out=plugins=grpc: add grpc server api
	OUT="--go_out=plugins=micro:."
	if [[ ! $MIRCO ]]; then
		OUT="--go_out=plugins=grpc:."
	fi
	protoc $IMPORT \
	  $OUT \
	  $FILEPATH
}

function CreateGatewaynSwagger(){
	# gw and swagger
	# Note HttpRule is essential, if no HttpRule found that you can generate gw file
	protoc $IMPORT \
	  --grpc-gateway_out=logtostderr=true:. \
	  --swagger_out=logtostderr=true,use_go_templates=true:. \
	  $FILEPATH
}

function CreateMirco(){
	protoc $IMPORT \
	  --micro_out=. \
	  $FILEPATH
}

function checkSafe(){
	PROTOs=$(ls | egrep -c "$FILEPATH")
	if [ $PROTOs -gt 1 ]; then
		FN=$(ls | egrep "$FILEPATH")
		echo "Found $PROTOs proto file."
		echo "$FN"
		read -p "Continue? [Y/n] " ans
		case "$ans" in
		y | Y | "")
			echo "proceeding ..."
			;;
		n | N)
			echo "exiting..."
			exit 1
			;;
		*)
			echo "invalid response"
			checkSafe
			;;
		esac
	fi

}

function DeployContainers(){
	# docker
	# TODO move to other script file
	exit 0
}


IMPORT_="-I. \
	    -I$GOPATH/src \
	    -I$GOPATH/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
	    "
while getopts "h?f:i:mg" opt; do
	case "$opt" in
		f)
			FILEPATH=$OPTARG
			;;
		i)
			IMPORT="$IMPORT_ -I$OPTARG"
			;;
		m)
			MIRCO=true
			;;
		g)
			GATEWAY=true
			;;
		h | \? | help)
			printHelp
			exit 0
			;;
	esac
done

: ${FILEPATH:="*.proto"}

checkSafe
CreateProtofile
if [ $MIRCO ]; then
	CreateMirco
fi

if [ $GATEWAY ]; then
	CreateGatewaynSwagger
fi