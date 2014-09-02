# Code Camp Server #

This project exists to spike a number of ideas i've had around structuring MVC apps as well as experimenting with continuous integration and delivery and azure.

## Setting up ##

Run `scripts/Initialize-Environment.ps1` from a powershell prompt. 

This will create an IIS Site with the following bindings:

- http://codecampserver.localtest.me:1337
- https://codecampserver.localtest.me:1338

A trusted self signed certifcate will also be generated and imported