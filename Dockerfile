FROM ubuntu:16.04
LABEL maintainer="Henry Tran"
LABEL version="1.0.1"
LABEL description="Henry Tran"

ENV DEBIAN_FRONTEND noninteractive
ENV NODE_VERSION "8.11 8.12"
ENV DEFAULT_NODE_VERSION 8.12
ENV PHP_VERSIONS php7.2

# Composer configs.
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_CACHE_DIR /mnt/composer_cache
ENV COMPOSER_PROCESS_TIMEOUT 2000

# Add the docker user
ENV HOME /home/docker
RUN useradd docker && passwd -d docker && adduser docker sudo
RUN mkdir -p $HOME && chown -R docker:docker $HOME

# Install base tools.
RUN apt-get -yqq update && \
    apt-get -yqq install \
        procps \
        curl \
        ca-certificates \
        wget \
        ghostscript \
        gnupg \
        locales \
        apt-utils \
        sudo \
        build-essential \
        patch \
        dkms \
        supervisor \
        mysql-client \
        git \
        vim \
        nano \
        zip \
        unzip \
        openssh-client \
        ssmtp

# Install ssh server.
RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile
# ADD ssh keys needed for connections to external servers
RUN mkdir -p $HOME/.ssh
VOLUME [ "$HOME/.ssh" ]
RUN echo "    IdentityFile $HOME/.ssh/id_rsa" >> /etc/ssh/ssh_config

USER root

# Install php https://tecadmin.net/install-php-7-on-ubuntu/
RUN apt-get update
RUN apt-get install -y software-properties-common
# add this ppa
RUN  add-apt-repository ppa:nilarimogard/webupd8
RUN  apt-get update && apt-get install launchpad-getkeys
# run it
RUN launchpad-getkeys

RUN \
    apt-get update && \
    apt-get install -y software-properties-common python-software-properties && \
    LC_ALL=C.UTF-8 add-apt-repository -y -u ppa:ondrej/php && \
    apt-get update && \
    apt-get -qq install -yqq  ${PHP_VERSIONS}-dev ${PHP_VERSIONS}-gmp libapache2-mod-${PHP_VERSIONS} ${PHP_VERSIONS}-common ${PHP_VERSIONS}-bcmath ${PHP_VERSIONS}-bz2 ${PHP_VERSIONS}-curl ${PHP_VERSIONS}-cli ${PHP_VERSIONS}-gd ${PHP_VERSIONS}-intl ${PHP_VERSIONS}-json ${PHP_VERSIONS}-mysql ${PHP_VERSIONS}-mbstring ${PHP_VERSIONS}-opcache ${PHP_VERSIONS}-xdebug ${PHP_VERSIONS}-xml ${PHP_VERSIONS}-xmlrpc ${PHP_VERSIONS}-zip

# Add additional php configuration file
ADD config/php.ini /etc/php/7.2/mods-available/php.ini
RUN phpenmod php
#RUN update-alternatives --set php /usr/bin/php7.2

# Install Apache web server
RUN apt-get -yqq install apache2

# Install PEAR package manager
RUN apt-get -yqq install php-pear && pear channel-update pear.php.net && pear upgrade-all

# Install PECL package manager
RUN apt-get -yqq install libpcre3-dev

RUN apt-get -yqq install gcc make autoconf libc-dev pkg-config
RUN apt-get -yqq install libmcrypt-dev libyaml-dev
RUN pecl install mcrypt-1.0.1

# Install YAML extension
#RUN pecl install yaml-2.0.0 && echo "extension=yaml.so" > /etc/php/7.2/mods-available/php.ini

# Install APCu extension
RUN pecl install apcu-5.1.8

# Install memcached service
RUN apt-get -yqq install memcached php-memcached

# Installation of Composer
RUN cd /usr/src && curl -sS http://getcomposer.org/installer | php
RUN cd /usr/src && mv composer.phar /usr/bin/composer

# Install composer parallel install plugin.
RUN composer global require hirak/prestissimo

# Installation of drush 9
RUN git clone https://github.com/drush-ops/drush.git /usr/local/src/drush
RUN cp -r /usr/local/src/drush/ /usr/local/src/drush9/
RUN cd /usr/local/src/drush9 && git checkout 9.1.0
RUN cd /usr/local/src/drush9 && composer update && composer install
RUN ln -s /usr/local/src/drush9/drush /usr/bin/drush

# Install drush launcher.
RUN composer global remove drush/drush
RUN composer global require "drush/drush-launcher:@stable"

ADD config/.bash_profile $HOME/.bash_profile

# Add sudo to www-data
RUN echo 'www-data ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Install sass and gem dependency
RUN apt-get install --fix-missing automake ruby2.3-dev libtool -y

# SASS and Compass installation
RUN gem install sass -v 3.5.6 ;\
    gem install compass;

# Installation node.js avoid using apt-get
#RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
#	apt-get update && apt-get install -y nodejs && \
#	npm install npm@latest -g

RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
SHELL ["/bin/bash", "-c", "-l"]
#RUN nvm install $NODE_VERSION
RUN for n in $NODE_VERSION; do nvm install $n; done
RUN nvm use $DEFAULT_NODE_VERSION
RUN nvm alias default $DEFAULT_NODE_VERSION

# Installation of Grunt
RUN npm install -g grunt-cli

# Installation of Gulp
RUN npm install gulp-cli -g

# Install Yarn and webpack
#SHELL ["/bin/bash", "-c"]
#RUN apt-get install -yqq apt-transport-https ca-certificates wget
#RUN echo deb https://dl.yarnpkg.com/debian/ stable main >> /etc/apt/sources.list.d/yarn.list
#RUN wget -O- https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
#RUN apt-get update && apt-get -yqq install yarn && \
#    yarn add webpack --dev

# Install phpunit test.
RUN composer global require phpunit/phpunit ^5.7 --no-progress --no-scripts --no-interaction

# Install Behat test.
COPY config/composer.json /opt/behat/composer.json

RUN cd /opt/behat && \
	composer install 2>&1
ENV PATH $PATH:/opt/behat/bin

#RUN rm -rf /var/www/html && \
#  mkdir -p /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html && \
#  chown -R www-data:www-data /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html

RUN mkdir -p /var/lock/apache2 /var/run/apache2 /var/log/apache2 && \
  chown -R www-data:www-data /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www

# Installation of PHP_CodeSniffer with Drupal coding standards.
# See https://www.drupal.org/node/1419988#coder-composer
#RUN composer global require drupal/coder
#RUN ln -s ~/.composer/vendor/bin/phpcs /usr/local/bin
#RUN ln -s ~/.composer/vendor/bin/phpcbf /usr/local/bin
#RUN phpcs --config-set installed_paths ~/.composer/vendor/drupal/coder/coder_sniffer

USER root

# Install zsh / OH-MY-ZSH
RUN apt-get -yqq install zsh && git clone git://github.com/robbyrussell/oh-my-zsh.git $HOME/.oh-my-zsh

# Cleanup some things
RUN apt-get -yqq autoremove; apt-get -yqq autoclean; apt-get clean

# Expose some ports to the host system (web server, ssh, Xdebug)
EXPOSE 80 22 9000

# Expose web root as volume
VOLUME ["/var/www"]

# Set timezone

ENV TZ=Australia/Melbourne
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN dpkg-reconfigure --frontend noninteractive tzdata

# Add apache web server configuration file
ADD config/httpd.conf /etc/apache2/conf-available/httpd.conf

# Configure needed apache modules, disable default sites and enable custom site
RUN a2enmod rewrite headers expires && a2dismod status && a2dissite 000-default && a2enconf httpd

# Add memcached configuration file
ADD config/memcached.conf /etc/memcached.conf

# Add ssmtp configuration file
ADD config/ssmtp.conf /etc/ssmtp/ssmtp.conf

# Add git global configuration files
ADD config/.gitconfig $HOME/.gitconfig
ADD config/.gitignore $HOME/.gitignore

# Add drush global configuration file
ADD config/drushrc.php $HOME/.drush/drushrc.php

# Add zsh configuration
ADD config/.zshrc $HOME/.zshrc

# Add bashrc configuration
ADD config/.bashrc $HOME/.bashrc

# Change file owner to docker guys.
RUN chown docker:docker $HOME/.zshrc
RUN chown docker:docker $HOME/.bash_profile

# chmod composer_cache folder fixed composer and drush command permission denied.
RUN chmod -R 777 /mnt
RUN chmod -R 777 ~/.drush

# Add startup script
ADD startup.sh $HOME/startup.sh

# Run npm from make command.
RUN ln -s /home/docker/.nvm/versions/node/v8.12.0/bin/node /usr/bin/node

# Install Supervisor.
RUN mkdir -p /var/log/supervisor
# Supervisor configuration
ADD config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Entry point for the container
RUN chown -R docker:docker $HOME && chmod +x $HOME/startup.sh

USER docker
ENV SHELL /bin/zsh
WORKDIR /var/www
CMD ["/bin/bash", "-c", "$HOME/startup.sh"]

