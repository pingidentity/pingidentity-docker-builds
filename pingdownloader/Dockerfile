FROM alpine
RUN apk --no-cache add curl
COPY get-bits.sh /
VOLUME /tmp
ENTRYPOINT ["/get-bits.sh"]
CMD ["--help"]