# encoding: utf-8
# author: Dominik Richter
# author: Christoph Hartmann

require 'helper'
require 'inspec/profile_context'

describe Inspec::ProfileContext do
  let(:backend) { MockLoader.new.backend }
  let(:profile) { Inspec::ProfileContext.new(nil, backend) }

  it 'must be able to load empty content' do
    profile.load('', 'dummy', 1).must_be_nil
  end

  describe 'its default DSL' do
    def load(call)
      proc { profile.load(call) }
    end

    it 'must provide os resource' do
      load('print os[:family]').must_output 'ubuntu'
    end

    it 'must provide file resource' do
      load('print file("").type').must_output 'unknown'
    end

    it 'must provide command resource' do
      load('print command("").stdout').must_output ''
    end

    it 'provides the describe keyword in the global DSL' do
      load('describe true do; it { should_eq true }; end')
        .must_output ''
      profile.rules.keys.length.must_equal 1
      profile.rules.keys[0].must_match /^\(generated from unknown:1 [0-9a-f]+\)$/
      profile.rules.values[0].must_be_kind_of Inspec::Rule
    end

    it 'loads multiple computed calls to describe correctly' do
      load("%w{1 2 3}.each do\ndescribe true do; it { should_eq true }; end\nend")
        .must_output ''
      profile.rules.keys.length.must_equal 3
      [0, 1, 2].each do |i|
        profile.rules.keys[i].must_match /^\(generated from unknown:2 [0-9a-f]+\)$/
        profile.rules.values[i].must_be_kind_of Inspec::Rule
      end
    end

    it 'does not provide the expect keyword in the global DLS' do
      load('expect(true).to_eq true').must_raise NoMethodError
    end

    it 'provides the rule keyword in the global DSL' do
      profile.load('rule 1')
      profile.rules.keys.must_equal [1]
      profile.rules.values[0].must_be_kind_of Inspec::Rule
    end
  end

  describe 'rule DSL' do
    let(:rule_id) { rand.to_s }

    it 'doesnt add any checks if none are provided' do
      profile.load("rule #{rule_id.inspect}")
      rule = profile.rules[rule_id]
      rule.instance_variable_get(:@checks).must_equal([])
    end

    describe 'adds a check via describe' do
      let(:cmd) {<<-EOF
        rule #{rule_id.inspect} do
          describe os[:family] { it { must_equal 'ubuntu' } }
        end
      EOF
      }
      let(:check) {
        profile.load(cmd)
        rule = profile.rules[rule_id]
        rule.instance_variable_get(:@checks)[0]
      }

      it 'registers the check with describe' do
        check[0].must_equal 'describe'
      end

      it 'registers the check with the describe argument' do
        check[1].must_equal %w{ubuntu}
      end

      it 'registers the check with the provided proc' do
        check[2].must_be_kind_of Proc
      end
    end

    describe 'adds a check via expect' do
      let(:cmd) {<<-EOF
        rule #{rule_id.inspect} do
          expect(os[:family]).to eq('ubuntu')
        end
      EOF
      }
      let(:check) {
        profile.load(cmd)
        rule = profile.rules[rule_id]
        rule.instance_variable_get(:@checks)[0]
      }

      it 'registers the check with describe' do
        check[0].must_equal 'expect'
      end

      it 'registers the check with the describe argument' do
        check[1].must_equal %w{ubuntu}
      end

      it 'registers the check with the provided proc' do
        check[2].must_be_kind_of Inspec::ExpectationTarget
      end
    end

    describe 'adds a check via describe + expect' do
      let(:cmd) {<<-EOF
        rule #{rule_id.inspect} do
          describe 'the actual test' do
            expect(os[:family]).to eq('ubuntu')
          end
        end
      EOF
      }
      let(:check) {
        profile.load(cmd)
        rule = profile.rules[rule_id]
        rule.instance_variable_get(:@checks)[0]
      }

      it 'registers the check with describe' do
        check[0].must_equal 'describe'
      end

      it 'registers the check with the describe argument' do
        check[1].must_equal ['the actual test']
      end

      it 'registers the check with the provided proc' do
        check[2].must_be_kind_of Proc
      end
    end
  end
end
