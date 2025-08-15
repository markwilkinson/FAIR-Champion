FROM ruby:3.3.0

# Set environment variables for locale
ENV LANG="en_US.UTF-8" LANGUAGE="en_US:UTF-8" LC_ALL="C.UTF-8"

# Update package lists and install dependencies in a single RUN to reduce layers
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends \
    build-essential \
    nano \
    libxml++2.6-dev \
    libraptor2-0 \
    libxslt1-dev \
    locales \
    software-properties-common \
    cron && \
    apt-get clean

# Update RubyGems and install Bundler
RUN gem update --system && \
    gem install bundler:2.3.12

# Create and set working directory
RUN mkdir /server
WORKDIR /server

# Copy application code and install dependencies
COPY . /server
RUN bundle install

# Set entrypoint
ENTRYPOINT ["sh", "/server/entrypoint.sh"]