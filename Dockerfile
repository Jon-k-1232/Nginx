# Use the Nginx image from Docker Hub
FROM nginx:latest

# Remove the default Nginx configuration file
RUN rm /etc/nginx/conf.d/default.conf

# Create SSL directory
RUN mkdir -p /etc/nginx/ssl

# Copy SSL certificates
COPY ./Server_ssl/ds2.kimmeloffice.com.crt /etc/nginx/ssl/
COPY ./Server_ssl/ds2.kimmeloffice.com.key /etc/nginx/ssl/
COPY ./Server_ssl/ds2.app.local.crt /etc/nginx/ssl/
COPY ./Server_ssl/ds2.app.local.key /etc/nginx/ssl/
COPY ./Server_ssl/pipelines.app.local.crt /etc/nginx/ssl/
COPY ./Server_ssl/pipelines.app.local.key /etc/nginx/ssl/

# Replace with our own custom configuration file
COPY ./default.conf /etc/nginx/conf.d/
