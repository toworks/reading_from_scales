# Имя программы, может передаваться из переменной
BUILD_NAME ?= reading_scales
# Директория для развертывания
DEST_DIR := deploy/
# Получение текущего коммита git
COMMIT := $(shell git rev-parse --short HEAD)
# Указание версии
VERSION := $(shell git describe --abbrev=0)
# Указание типа релиза, может передаваться из переменной
RELEASE_TYPE ?= testing
# Время сборки, может передаваться из переменной
BUILD_DATE ?= $(shell date +%Y%m%d)
# Фалы для развертывания
DEPLOY_FILES := ${BUILD_NAME} configs/${RELEASE_TYPE}/${BUILD_NAME}.conf.yml service/${BUILD_NAME}.service

build:
	go build -ldflags "-s -w -X 'main.VERSION=${VERSION}' -X 'main.COMMIT=${COMMIT}' -X 'main.BUILD_DATE=${BUILD_DATE}'" -o ${BUILD_NAME} .

run:
	./${BUILD_NAME}

#build_and_run: build run

compile:
	GOARCH=amd64 GOOS=darwin  go build -ldflags "-s -w" -o ${BUILD_NAME} .
	GOARCH=amd64 GOOS=linux   go build -ldflags "-s -w" -o ${BUILD_NAME} .
	GOARCH=amd64 GOOS=windows go build -ldflags "-s -w" -o ${BUILD_NAME}.exe .
	GOARCH=386   GOOS=windows go build -ldflags "-s -w" -o ${BUILD_NAME}.exe .

install: ${DEPLOY_FILES}
	mkdir -p ${DEST_DIR}
	for f in ${DEPLOY_FILES}; do echo $$f;  cp -f $$f ${DEST_DIR}; done

clean:
	go clean
	rm -r ${DEST_DIR}

