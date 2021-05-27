# Rails Templates
## Minimal with Bootstrap 5

Get a minimal rails app ready to be deployed on Heroku with Bootstrap, Simple form and debugging gems.

```bash
rails new \
  --database postgresql \
  --webpack \
  -m https://raw.githubusercontent.com/dogaruemiliano/rails-TEMPLATES/master/bootstrap.rb \
  CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```

## Devise

Same as minimal **plus** a Devise install with a generated `User` model.

```bash
rails new \
  --database postgresql \
  --webpack \
  -m https://raw.githubusercontent.com/dogaruemiliano/rails-TEMPLATES/master/devise.rb \
  CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```
