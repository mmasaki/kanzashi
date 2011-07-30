module Kanzashi
  module Config
    include Kanzashi
    DEFAULT = {
      config_file: "config.yml",
      user: {
        nick: "kanzashi",
        user: "kanzashi",
        real: "kanzashi that better tiarra"
      },
      server: {
        port: 8082,
        bind: "0.0.0.0",
        pass: nil,
        tls: false
      },
      log: {},
      networks: {},
      plugins: {}
    }.freeze
    @@config = Util::CustomHash.new(DEFAULT)
    @@old_config = nil

    class << self
      def reset
        @@old_config = nil
        @@config = Util::CustomHash.new(DEFAULT)
        self
      end

      def load_config(str=nil)
        @@old_config = Util::CustomHash.new(@@config)
        file = str || open(@@config[:config_file])
        yaml = Util::CustomHash.new(YAML.load(file)||{})
        yaml.delete :config_file
        [:user,:server].each do |k|
          if (_ = yaml.delete(k))
            @@config[k].merge! _
          end
        end
        @@config.merge! yaml
        @@config = Util::CustomHash.new(@@config)
      end

      def config
        @@old_config ? @@config : load_config
      end

      def parse(argv)
        parser = OptionParser.new
        config_file = "config.yml"

        parser.on('-c FILE','--config=FILE','specify config file') do |file|
          @@config[:config_file] = file
        end

        parser.parse(argv)

        load_config
        self
      end
    end
  end
end
