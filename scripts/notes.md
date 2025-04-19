# Notes

## Devcontainer

### Stuck at onboardning

```js
fetch("http://localhost:7123/api/onboarding/integration", {
  headers: {
    Accept: "*/*",
    "User-Agent":
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36",
    Authorization:
      "Bearer INSERT_ACCESS_TOKEN_FROM_TOKEN_CALL_IN_NETWORK_TAB_HERE",
  },
  body: '{"client_id": "http://localhost:7123/", "redirect_uri": "http://localhost:7123/?auth_callback=1"}',
  method: "POST",
});
```

## UTM VM

### Mount add-on in Home Assistant OS VM

```shell
# on Host (MacOS)
find . -path './.git' -prune -o -exec xattr -d user.virtfs.uid {} \; 2>/dev/null
find . -path './.git' -prune -o -exec xattr -d user.virtfs.gid {} \; 2>/dev/null
find . -path './.git' -prune -o -exec xattr -w -x user.virtfs.uid 00000000 {} \;
find . -path './.git' -prune -o -exec xattr -w -x user.virtfs.gid 00000000 {} \;

# in Guest (Home Assistant OS VM)
mkdir -p /addons/local
mount -t 9p -o trans=virtio,version=9p2000.L,uid=$(id -u),gid=$(id -g),access=client,cache=none share /root/addons/local
```
