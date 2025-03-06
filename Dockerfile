# Use the latest Mono image
FROM mono:latest

LABEL maintainer="Marcos Junior <junalmeida@gmail.com>"

# Install required dependencies
RUN apt-get update && apt-get install -y \
    iproute2 supervisor ca-certificates-mono \
    nuget msbuild referenceassemblies-pcl mono-fastcgi-server4 nginx nginx-extras \
  && rm -rf /var/lib/apt/lists/* /tmp/* \
  && echo "daemon off;" | tee -a /etc/nginx/nginx.conf \
  && sed -i -e 's/www-data/root/g' /etc/nginx/nginx.conf

# Set working directory inside the container
WORKDIR /app

# Copy solution and project files first to restore dependencies before copying everything
COPY sample/src/sample-app.sln ./
COPY sample/src/sample-app/sample-app.csproj sample-app/sample-app.csproj
COPY sample/src/sample-app/packages.config sample-app/packages.config

# Ensure the packages directory exists
RUN mkdir -p /app/packages

# Debugging: List directory contents before running NuGet
RUN ls -R

# Restore NuGet packages
RUN nuget restore sample-app.sln
RUN nuget install sample-app/packages.config -OutputDirectory /app/packages

RUN cat sample-app/sample-app.csproj

# Copy the rest of the project files
COPY sample/src/sample-app/ sample-app/

# Build the MVC project
RUN msbuild sample-app/sample-app.csproj /p:Configuration=Release /p:OutputPath=/app/build

# Ensure the built application is copied to the correct directory
RUN mkdir -p /var/www/sample-app && cp -r /app/build/_PublishedWebsites/sample-app/* /var/www/sample-app/


# Copy NGINX and Supervisor configurations
COPY nginx/ /etc/nginx/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose the web server port
EXPOSE 80

# Start supervisord to manage NGINX and Mono FastCGI
ENTRYPOINT [ "/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf" ]
