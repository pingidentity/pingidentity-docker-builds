FROM pingidentity/pingdownloader as staging
RUN /get-bits.sh -p delegator -v 3.0.2 \
    && unzip /tmp/product.zip -d /tmp \
    && mv /tmp/delegator /opt/server


FROM nginx:stable-alpine as pingdelegatedadmin
LABEL	maintainer=devops_program@pingidentity.com \
		license="Ping Identity Proprietary" \
		vendor="Ping Identity Corp." \
		name="Ping Identity PingDelegatedAdmin (Alpine/OpenJDK8) Image"
EXPOSE 80
EXPOSE 443
ENV SERVER_PROFILE_URL=""

RUN apk --no-cache add git curl ca-certificates
VOLUME /opt/in
COPY entrypoint.sh /opt
COPY --from=staging /opt/server/app /usr/share/nginx/html/delegator
COPY index.html /usr/share/nginx/html/index.html
ENTRYPOINT [ "/opt/entrypoint.sh" ]
CMD ["start-server"]
