require_relative './helper'

describe Kanzashi::Util do
  describe Kanzashi::Util::CustomHash do
    describe ".new" do
      it "converts Hash to CustomHash" do
        Kanzashi::Util::CustomHash.new({a: {b: :c}}).a.should \
          be_a_kind_of(Kanzashi::Util::CustomHash)
      end

      it "converts Array to CustomArray" do
        Kanzashi::Util::CustomHash.new({a: [:b]}).a.should \
          be_a_kind_of(Kanzashi::Util::CustomArray)
      end

      it "converts String key to Symbol key" do
        Kanzashi::Util::CustomHash.new({"a" => :b})[:a].should == :b
      end

      it "converts all things includes nested" do
        the_hash = Kanzashi::Util::CustomHash.new({
          a: [{:b  => [:c],
               "c" => {:d  => :e,
                       "f" => :g}
              }]
        })
        the_hash.a.should            be_a_kind_of(Kanzashi::Util::CustomArray)
        the_hash.a[0].b.should       be_a_kind_of(Kanzashi::Util::CustomArray)
        the_hash.a[0].should         be_a_kind_of(Kanzashi::Util::CustomHash)
        the_hash.a[0][:c].should     be_a_kind_of(Kanzashi::Util::CustomHash)
        the_hash.a[0][:c][:f].should == :g
      end
    end

    describe ".method_missing" do
      it "refers key" do
        Kanzashi::Util::CustomHash.new({a: :b}).a.should == :b
      end
    end
  end

  describe Kanzashi::Util::CustomArray do
    describe ".new" do
      it "converts Hash to CustomHash" do
        Kanzashi::Util::CustomArray.new([{a: :b}])[0].should \
          be_a_kind_of(Kanzashi::Util::CustomHash)
      end
    end
  end

  describe Kanzashi::UtilMethod do
    describe ".parse_prefix" do
      it "return nick, user, host" do
        Kanzashi::UtilMethod.parse_prefix("nick!user@host").should == ["nick", "user", "host"]
      end
    end
  end

  describe Kanzashi do
    describe ".c" do
      it "returns configration of plugin" do
        Kanzashi::Config.load_config <<-EOF
plugins:
  haruharu:
    enabled: false
    hi: hola
        EOF
        Kh.make_space(:haruharu) do
          K.c.hi.should == "hola"
        end
      end
    end
  end
end
