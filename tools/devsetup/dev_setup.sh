#!/bin/bash

set -e

echo "Host/path to postgres:"
read PGH
echo "Port:"
read PGP
echo "Database:"
read PGD
echo "User:"
read PGU

echo Verifying postgres connection...
psql -w "host=$PGH port=$PGP dbname=$PGD user=$PGU" -c "SELECT 1" >/dev/null

echo Verifying that pgcrypto is installed in the pgcrypto schema...
psql -w "host=$PGH port=$PGP dbname=$PGD user=$PGU" -c "CREATE SCHEMA IF NOT EXISTS pgcrypto; CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA pgcrypto; SELECT pgcrypto.gen_random_uuid()"

# Start from script directory to be safe!
cd "${0%/*}"

virtualenv --no-site-packages venv_dev
venv_dev/bin/pip install -r dev_requirements.txt

cd ../..
cat > postgresqleu/local_settings.py <<EOF
DEBUG=True
DISABLE_HTTPS_REDIRECTS=True
DATABASES={
 'default': {
   'ENGINE': 'django.db.backends.postgresql_psycopg2',
   'NAME': '$PGD',
   'HOST': '$PGH',
   'PORT': '$PGP',
   'USER': '$PGU',
 }
}
SECRET_KEY='reallysecretbutwhocares'
SERVER_EMAIL='root@localhost'
SESSION_COOKIE_SECURE=False
SITEBASE="http://localhost:8000/"
EOF

ln -s tools/devsetup/venv_dev/bin/python .
./python manage.py migrate

cat tools/devsetup/devserver-uwsgi.ini.tmpl | sed -e "s#%DJANGO%#$(pwd)/tools/devsetup/venv_dev#g" > devserver-uwsgi.ini

echo
echo Creating a django superuser, and setting password!
./python manage.py createsuperuser

echo All ready to go. To start the development server, go to
pwd
echo and run:
echo uwsgi --ini devserver-uwsgi.ini
echo
echo or for a slightly more limited version:
echo ./python manage.py runserver
