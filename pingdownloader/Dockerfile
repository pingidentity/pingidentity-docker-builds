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