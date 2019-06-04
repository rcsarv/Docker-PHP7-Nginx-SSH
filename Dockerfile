FROM alpine:3.9
LABEL Maintainer="RC" \
      Description="Lightweight container with Nginx 1.14 & PHP-FPM 7.2 based on Alpine Linux."

# Install packages
RUN apk --no-cache add php7 php7-fpm php7-mysqli php7-json php7-openssl php7-curl \
    php7-zlib php7-xml php7-phar php7-intl php7-dom php7-xmlreader php7-ctype \
    php7-mbstring php7-gd nginx supervisor curl

#Install SSH
RUN apk update && apk add openssh-server
RUN mkdir /var/run/sshd
RUN echo 'root:PassWord@ChangeMe' | chpasswd
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
#RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN echo 'ClientAliveInterval 300' >> /etc/ssh/sshd_config
RUN echo  'ClientAliveCountMax 10' >> /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
#RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
#ENV NOTVISIBLE "in users profile"
#RUN echo "export VISIBLE=now" >> /etc/profile


# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY config/php.ini /etc/php7/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody.nobody /run && \
  chown -R nobody.nobody /var/lib/nginx && \
  chown -R nobody.nobody /var/tmp/nginx && \
  chown -R nobody.nobody /var/log/nginx

# Setup document root
RUN mkdir -p /var/www/html

# Switch to use a non-root user from here on
USER nobody

# Add application
WORKDIR /var/www/html
COPY --chown=nobody html/ /var/www/html/

# Expose the port nginx is reachable on
EXPOSE 8080

#SSH Port
EXPOSE 22

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf" ,  "/usr/sbin/sshd"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping
