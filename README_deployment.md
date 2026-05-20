# Deployment

## Overview

The steps below require a Linux server with Systemd. Eschewing Docker, a Systemd unit is used to run a fair-champion
service, with Nginx used as proxy pass. A TLS certificate is provided via Letsencrypt. 

## Environment
Check out the FAIR-Champion code and create .ruby-version and .ruby-gemset files in the top-level Champion directory.

Install RVM (https://rvm.io/) and create a fair-champion gemset. Add puma to the Gemfile (required to run the
fair-champion service) and run `bundle install`. 

At this point the Champion should run locally with `ruby run.rb`.

## Systemd

The unit file (/etc/systemd/system/fair-champion.service) is as follows:

```systemd
[Service]
User=your_username
WorkingDirectory=/home/your_username/FAIR-Champion
Environment=HOME=/home/your_username
ExecStart=/bin/bash -lc 'cd /home/your_username/FAIR-Champion && /home/your_username/.rvm/bin/rvm ruby-3.4.2@fair-champion do bundle exec ruby run.rb'
StandardOutput=append:/var/log/champion.log
StandardError=inherit

# environment entries 
Environment=PATH=/home/your_username/.rvm/gems/ruby-3.4.2@fair-champion/bin:/home/your_username/.rvm/gems/ruby-3.4.2@global/bin:/home/your_username/.rvm/rubies/ruby-3.4.2/bin:/home/your_username/.rvm/bin:/usr/local/bin:/usr/bin:/bin
Environment=GEM_HOME=/home/your_username/.rvm/gems/ruby-3.4.2@fair-champion
Environment=GEM_PATH=/home/your_username/.rvm/gems/ruby-3.4.2@fair-champion:/home/your_username/.rvm/gems/ruby-3.4.2@global

TimeoutSec=30
RestartSec=15s
Restart=always
ProtectClock=yes
ProtectHostname=yes
RemoveIPC=yes
```

## Nginx

Acquire your domain name. For the examples below champion.example.org will be used. 

In the top-level FAIR-Champion directory, `mkdir -p public/.well-known/acme-challenge/`.

Set up an Nginx hosts file in /etc/nginx/sites-available to redirect to https and to allow the initial setup of a 
certificate (e.g. champion.conf). The content should be as follows:

```nginx
server {
    # comment out this block when setting up the certificate, then uncomment
    # it once the certificate is working. 
    #if ($host = champion.example.org) {
    #        return 301 https://$host$request_uri;
    #} 

    listen 80;
    server_name champion.example.org;

    location ^~ /.well-known/acme-challenge/ {
        alias /home/your_username/FAIR-Champion/public/.well-known/acme-challenge/;
        index  index.html index.htm;
        allow all;
        default_type "text/plain";
    }

}
```

Symlink this into /etc/nginx/sites-enabled.

Check with `nginx -t` then `systemctl reload nginx`. At this point you may run 
`certbot certonly -d champion.example.org`

Uncomment the commented out redirect block in champion.conf. Create champion.tls.conf and symlink that as above.

```nginx
server {
    server_name champion.example.org;

    root /home/your_username/FAIR-Champion/public;

    listen 443 ssl; # default_server; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/champion.example.org/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/champion.example.org/privkey.pem; # managed by Certbot

    add_header Strict-Transport-Security "max-age=31536000" always;

    location ^~ /.well-known/acme-challenge/ {
        alias /home/your_username/FAIR-Champion/public/.well-known/acme-challenge/;
        index  index.html index.htm;
        allow all;
        default_type "text/plain";
    }
    location / {
        autoindex on;
        client_max_body_size 3M;
        add_header Permissions-Policy interest-cohort=();
        
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;

        proxy_pass http://localhost:4567;
  }
}
```

Check the configuration and re-start Nginx as above.

## Conclusion

That's it! Enjoy.

