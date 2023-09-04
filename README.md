# Ævintýri

Text adventure game engine built with Hare.

## Dependencies

Current this relies on a few 3rd party Hare modules that are not included in
the standard library, but they are vendored in with git submodules. In order to
compile it you need to sync the submodules code.

```
> git submodule --init --recursive
```

This will clone the dependencies into the `vendor` directory and Hare knows to
look in this directory when you specify a module with `use <module>`.

## Running

```
> hare run cmd/main.ha
```

## Connecting

You can connect to the server with Telnet.

```
> telnet 0.0.0.0 7913
Trying 0.0.0.0...
Connected to 0.0.0.0
Escape character is '^]'.
+----------------------+
| Welcome to Ævintýri! |
+----------------------+

» █
```

## Testing

```
> hare test
```