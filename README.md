Ghetto Package Management
-------------------------

A simple git-based package management system.


Package Specification
---------------------

Packages are defined in YAML, as follows:

	packages:
		package-name:
			build: true|false (default true)
			configure: true|false|Hash (default true)
				- "--flags for ./configure" (optional)
				- "--more!" (optional)