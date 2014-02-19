[![Code Climate](https://codeclimate.com/github/colstrom/gpm.png)](https://codeclimate.com/github/colstrom/gpm)

Ghetto Package Management
=========================

A package management system based on git and YAML.


Package Specification
=====================

Packages are defined in YAML, as follows:

	packages:
	  package-name:
	    build: true|false (default true)
	    configure: true|false|Hash (default true)
	      - "--flags for ./configure" (optional)
	      - "--more!" (optional)
	    local: category/name (required)
	    remote: "git remote" (required)
	    version: "version" (required)
	    install: true|false (default true)
	    preconfigure: (optional)
	      - "autoconf" (or whatever)
	    alternate_install: "atypical install command here" (optional)

Examples
========

PHP 5.5.9, with fpm, json, and openssl.
---------
	php: 
	  preconfigure:
	    - "./buildconf --force"
	  configure: 
	    - "--enable-fpm"
	    - "--enable-json"
	    - "--with-openssl"
	  local: lang/php
	  remote: "https://github.com/php/php-src.git"
	  version: php-5.5.9

supervisord
-----------
	  supervisor: 
	    alternate_install: "python setup.py install"
	    build: false
	    configure: false
	    local: sysutils/supervisor
	    remote: "https://github.com/Supervisor/supervisor.git"
	    version: 3.0

zsh
---
	  zsh: 
	    preconfigure:
	      -"autoconf"
	    configure: true
	    local: shells/zsh
	    remote: "https://github.com/zsh-users/zsh.git"
	    version: zsh-5.0.5

Licensing
=========
**gpm** is available under a permissive open-source license (MIT/X11). The packages it installs have their own licenses.