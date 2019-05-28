#- # Ping Identity Docker Image - `pingdelegator`
#- 
#- This docker image provides an nginx image with the PingDelegator
#- deployed to be used in configuration of the PingDirectory and 
#- PingFederate products.
#-
#- ## Related Docker Images
#- - `pingidentity/pingdownloader` - Image used to download ping product
#- - `nginx:alpine` - Alpine Nginx server to serve PingDelegator .war file
#-

FROM pingidentity/pingdownloader as staging
RUN /get-bits.sh -p delegator -v 3.0.2 \
    && unzip /tmp/product.zip -d /tmp \
    && mv /tmp/delegator /opt/server

FROM nginx:alpine
LABEL   maintainer=devops_program@pingidentity.com \
                license="Ping Identity Proprietary" \
                vendor="Ping Identity Corp." \
                name="Ping Identity (alpine/nginx) Image"

COPY --from=staging /opt/server/app /usr/share/nginx/html/delegator
COPY entrypoint.sh /opt/
COPY index.html /usr/share/nginx/html/

ENTRYPOINT [ "/opt/entrypoint.sh" ]
CMD ["start-server"]
