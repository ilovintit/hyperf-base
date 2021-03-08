FROM ubuntu:20.04

MAINTAINER ilovintit <ilovintit@gmail.com>

ENV DEBIAN_FRONTEND=noninteractive

COPY ./sources.list /etc/apt/sources.list

ENV SWOOLE_VERSION="4.5.2" \
    #  install and remove building packages
    PHPIZE_DEPS="autoconf dpkg-dev dpkg file g++ gcc libc-dev make php7.4-dev pkgconf re2c libtool automake libaio-dev unixodbc unixodbc-dev gnupg2 unzip zlib1g zlib1g-dev" \
    LD_LIBRARY_PATH=/usr/local/instantclient

RUN set -ex \
    && apt-get update \
    && apt-get install -y tzdata curl wget git\
    && ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && apt-get install -y php7.4 \
    php7.4-bcmath \
    php7.4-curl \
    php7.4-dom \
    php7.4-gd \
    php7.4-mbstring \
    php7.4-mysql \
    php7.4-redis \
    php7.4-zip \
    && apt-get install -y $PHPIZE_DEPS

COPY ./instantclient-sqlplus-linux.x64-12.2.0.1.0.zip /tmp
COPY ./instantclient-basic-linux.x64-12.2.0.1.0.zip /tmp
COPY ./instantclient-sdk-linux.x64-12.2.0.1.0.zip /tmp

RUN set -ex \
    && curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql17 mssql-tools \
    # install ext
    && unzip /tmp/instantclient-basic-linux.x64-12.2.0.1.0.zip -d /usr/local \
    && unzip /tmp/instantclient-sqlplus-linux.x64-12.2.0.1.0.zip -d /usr/local \
    && unzip /tmp/instantclient-sdk-linux.x64-12.2.0.1.0.zip -d /usr/local \
    && mv /usr/local/instantclient_12_2 /usr/local/instantclient \
    && ln -s /usr/local/instantclient/libclntsh.so.12.1 /usr/local/instantclient/libclntsh.so \
    && ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus \
    && ln -s /usr/local/instantclient/liblibocci.so.12.1 /usr/local/instantclient/libocci.so \
    && echo 'instantclient,/usr/local/instantclient' | pecl install oci8-2.2.0 sqlsrv pdo_sqlsrv xlswriter \
    && echo "extension=xlswriter.so" > /etc/php/7.4/cli/conf.d/60_xlswriter.ini \
    && echo "extension=sqlsrv.so" > /etc/php/7.4/cli/conf.d/00_sqlsrv.ini \
    && echo "extension=pdo_sqlsrv.so" > /etc/php/7.4/cli/conf.d/10_pdo_sqlsrv.ini \
    && echo "extension=oci8.so" > /etc/php/7.4/cli/conf.d/10_oci8.ini \
    # download
    && cd /tmp \
    && curl -SL "https://github.com/swoole/swoole-src/archive/v${SWOOLE_VERSION}.tar.gz" -o swoole.tar.gz \
    && ls -alh \
    # php extension:swoole
    && cd /tmp \
    && mkdir -p swoole \
    && tar -xf swoole.tar.gz -C swoole --strip-components=1 \
    && ( \
        cd swoole \
        && phpize \
        && ./configure --enable-mysqlnd --enable-openssl --enable-http2 \
        && make -s -j$(nproc) && make install \
    ) \
    && echo "memory_limit=1G" > /etc/php/7.4/cli/conf.d/00-default.ini \
    && echo "upload_max_filesize=1024M" > /etc/php/7.4/cli/conf.d/00-default.ini \
    && echo "post_max_size=1024M" > /etc/php/7.4/cli/conf.d/00-default.ini \
    && echo "extension=swoole.so" > /etc/php/7.4/cli/conf.d/50-swoole.ini \
    && echo "swoole.use_shortname = 'Off'" >> /etc/php/7.4/cli/conf.d/50-swoole.ini \
    # clear
    && rm -rf /tmp/* \
    && php -v \
    && php -m \
    && php --ri swoole

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && php -r "unlink('composer-setup.php');" \
    && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

