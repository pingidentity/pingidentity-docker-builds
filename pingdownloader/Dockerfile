#- # Ping Identity Docker Image - `pingdownloader`
#- 
#- This docker image provides an alpine image to help with the download of
#- Ping product images and licenses.
#-
#- ## Related Docker Images
#- - `alpine` - Parent Image
#-

FROM alpine
LABEL	maintainer=devops_program@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity (Alpine) Image"
RUN apk --no-cache add curl jq
COPY get-bits.sh /
VOLUME /tmp
ENTRYPOINT ["/get-bits.sh"]
CMD ["--help"]

#- ## Usage
#- ```shell
#- docker run pingidentity/pingdownloader -p <product_name>
#- ```
#- ### Options
#- ```shell 
#- -v, --version: the version of the product to download. by default, the downloader will pull the latest version
#- 
#- -c, --conserve-name: use this option to conserve the original file name. By   default, the downloader will rename the file product.zip
#- 
#- -n, --dry-run:	this will cause the URL to be displayed but the the bits not to be downloaded
#- 
#- ```
#- ## Examples
#- Download the latest PingDirectory
#- ```
#- docker run pingidentity/pingdownloader -p PingDirectory
#- ```
#- 
#- Download a specific version of PingDirectory
#- ```
#- docker run pingidentity/pingdownloader -p PingDirectory -v 7.3.0.0
#- ```
#- 
#- Download a product to /tmp on the host, as opposed to /tmp in the PingDownloader container
#- ```
#- docker run --rm -v /tmp:/tmp pingidentity/pingdownloader -p PingFederate
#- ```
