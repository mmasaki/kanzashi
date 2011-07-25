module Kanzashi
  module Config
    include Kanzashi
    @@config = {
      config_file: "config.yml",
      user: {
        nick: "kanzashi",
        user: "kanzashi",
        real: "kanzashi that better tiarra"
      },
      server: {
        port: 8081,
        bind: "0.0.0.0",
        pass: nil,
        tls: false
      },
      networks: {}
    }
    @@old_config = nil
    @@config = Util::CustomHash.new(@@config)

    class << self
      def load_config
        @@old_config = @@config.dup
        yaml = Util::CustomHash.new(YAML.load(open(@@config[:config_file])))
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
