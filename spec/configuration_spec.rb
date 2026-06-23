require 'spec_helper'

RSpec.describe Configuration do
  around do |example|
    original_env = ENV.to_hash
    example.run
  ensure
    ENV.replace(original_env)
  end

  describe '.env' do
    it 'returns the configured Rack environment' do
      ENV['RACK_ENV'] = 'test'

      expect(described_class.env).to eq('test')
    end

    it 'defaults to development' do
      ENV.delete('RACK_ENV')

      expect(described_class.env).to eq('development')
    end
  end

  describe '.test_host' do
    it 'returns the configured test host' do
      ENV['TEST_HOST'] = 'https://tests.example.org'

      expect(described_class.test_host).to eq('https://tests.example.org')
    end

    it 'defaults to the OSTrails test host' do
      ENV.delete('TEST_HOST')

      expect(described_class.test_host).to eq('https://tests.ostrails.eu/tests')
    end
  end

  describe '.champ_host' do
    it 'returns the configured Champion host' do
      ENV['CHAMP_HOST'] = 'https://champion.example.org'

      expect(described_class.champ_host).to eq('https://champion.example.org')
    end

    it 'defaults to the OSTrails Champion host' do
      ENV.delete('CHAMP_HOST')

      expect(described_class.champ_host).to eq('https://tools.ostrails.eu/champion')
    end
  end

  describe '.champion_host' do
    it 'returns the configured public Champion host' do
      ENV['CHAMPION_HOST'] = 'https://public-champion.example.org'

      expect(described_class.champion_host).to eq('https://public-champion.example.org')
    end

    it 'defaults to the OSTrails Champion host' do
      ENV.delete('CHAMPION_HOST')

      expect(described_class.champion_host).to eq('https://tools.ostrails.eu/champion')
    end
  end

  describe '.fdpindex_sparql' do
    it 'returns the configured FDP index SPARQL endpoint' do
      ENV['FDPINDEX_SPARQL'] = 'https://example.org/repositories/fdp'

      expect(described_class.fdpindex_sparql).to eq('https://example.org/repositories/fdp')
    end

    it 'defaults to the OSTrails FDP index SPARQL endpoint' do
      ENV.delete('FDPINDEX_SPARQL')

      expect(described_class.fdpindex_sparql).to eq('https://tools.ostrails.eu/repositories/fdpindex-fdp')
    end
  end

  describe '.fdp_index_proxy' do
    it 'returns the configured FDP index proxy endpoint' do
      ENV['FDPINDEXPROXY'] = 'https://example.org/fdp-index-proxy'

      expect(described_class.fdp_index_proxy).to eq('https://example.org/fdp-index-proxy')
    end

    it 'defaults to the OSTrails FDP index proxy endpoint' do
      ENV.delete('FDPINDEXPROXY')

      expect(described_class.fdp_index_proxy).to eq('https://tools.ostrails.eu/fdp-index-proxy/proxy')
    end
  end
end
