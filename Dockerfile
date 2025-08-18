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
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Update RubyGems and install Bundler
RUN gem update --system && \
    gem install bundler:2.3.12

# Create and set working directory
WORKDIR /server

# Copy Gemfile and Gemfile.lock first to cache bundle install
COPY Gemfile Gemfile.lock fair-champion.gemspec /server/
RUN bundle install

# Copy the rest of the application code
COPY . /server

# Set entrypoint
ENTRYPOINT ["sh", "/server/entrypoint.sh"]