# Using the Justice Dialer Login Iframe

To embed a widget that can be used to claim logins on your candidate's site (as
seen on https://moserforcongress.com/phonebank-laura-moser/ or https://www.electcrowe.com/phonebank/)
you must create an iframe with the src `https://justicedialer.com/login-iframe/jd`, like:

```
<iframe src="https://justicedialer.com/login-iframe/jd" style="width:100%;height:100%;">
```

## Extra Post Sign Information

By default, the login iframe will display the username and password back to the user.
If you would like to include extra content on that page, host that content somewhere on
the internet as a standalone site or page on your existing site.

Grab the url for that content, and include it in the iframe src as ?post_sign=mysite.com, so it is:

```
<iframe src="https://justicedialer.com/login-iframe/jd?post_sign=mysite.com" >
```

Then, after someone claims a login, the page `mysite.com` will be included below the username and password.

To see an example, claim a login on https://justicedialer.com/login-iframe/jd?post_sign=https://en.wikipedia.org.

For something fun, check out https://justicedialer.com/login-iframe/jd?post_sign=https://justicedialer.com/login-iframe/jd?post_sign=https://justicedialer.com/login-iframe/jd
