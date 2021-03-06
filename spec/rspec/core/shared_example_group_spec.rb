require 'spec_helper'

module RSpec::Core
  describe SharedExampleGroup do
    
    ExampleModule = Module.new
    ExampleClass = Class.new

    %w[share_examples_for shared_examples_for].each do |method_name|
      describe method_name do
        it "is exposed to the global namespace" do
          Kernel.should respond_to(method_name)
        end

        it "raises an ArgumentError when adding a second shared example group with the same name" do
          group = ExampleGroup.describe('example group')
          group.send(method_name, 'shared group') {}
          lambda do
            group.send(method_name, 'shared group') {}
          end.should raise_error(ArgumentError, "Shared example group 'shared group' already exists")
        end
        
        ["name", :name, ExampleModule, ExampleClass].each do |object|
          type = object.class.name.downcase
          context "given a #{type}" do
            it "captures the given #{type} and block in the World's collection of shared example groups" do
              implementation = lambda {}
              RSpec.world.shared_example_groups.should_receive(:[]=).with(object, implementation)
              send(method_name, object, &implementation)
            end
          end
        end

        context "given a hash" do
          it "delegates extend on configuration" do
            implementation = Proc.new { def bar; 'bar'; end }
            send(method_name, :foo => :bar, &implementation)
            a = RSpec.configuration.include_or_extend_modules.first
            a[0].should eq(:extend)
            Class.new.extend(a[1]).new.bar.should eq('bar')
            a[2].should eq(:foo => :bar)
          end
        end

        context "given a string and a hash" do
          it "captures the given string and block in the World's collection of shared example groups" do
            implementation = lambda {}
            RSpec.world.shared_example_groups.should_receive(:[]=).with("name", implementation)
            send(method_name, "name", :foo => :bar, &implementation)
          end

          it "delegates extend on configuration" do
            implementation = Proc.new { def bar; 'bar'; end }
            send(method_name, "name", :foo => :bar, &implementation)
            a = RSpec.configuration.include_or_extend_modules.first
            a[0].should eq(:extend)
            Class.new.extend(a[1]).new.bar.should eq('bar')
            a[2].should eq(:foo => :bar)
          end
        end
      end
    end

    describe "#it_should_behave_like" do
      it "creates a nested group" do
        shared_examples_for("thing") {}
        group = ExampleGroup.describe('fake group')
        group.it_should_behave_like("thing")
        group.should have(1).children
      end
      
      it "creates a nested group for a class" do
        shared_examples_for(ExampleClass) {}
        group = ExampleGroup.describe('fake group')
        group.it_should_behave_like(ExampleClass)
        group.should have(1).children
      end

      it "adds shared examples to nested group" do
        shared_examples_for("thing") do
          it("does something")
        end
        group = ExampleGroup.describe('fake group')
        shared_group = group.it_should_behave_like("thing")
        shared_group.should have(1).examples
      end

      it "adds shared instance methods to nested group" do
        shared_examples_for("thing") do
          def foo; end
        end
        group = ExampleGroup.describe('fake group')
        shared_group = group.it_should_behave_like("thing")
        shared_group.public_instance_methods.map{|m| m.to_s}.should include("foo")
      end

      it "adds shared class methods to nested group" do
        shared_examples_for("thing") do
          def self.foo; end
        end
        group = ExampleGroup.describe('fake group')
        shared_group = group.it_should_behave_like("thing")
        shared_group.methods.map{|m| m.to_s}.should include("foo")
      end

      context "given some parameters" do
        it "passes the parameters to the shared example group" do
          passed_params = {}

          shared_examples_for("thing") do |param1, param2|
            it("has access to the given parameters") do
              passed_params[:param1] = param1
              passed_params[:param2] = param2
            end
          end

          group = ExampleGroup.describe("group") do
            it_should_behave_like "thing", :value1, :value2
          end
          group.run

          passed_params.should eq({ :param1 => :value1, :param2 => :value2 })
        end

        it "adds shared instance methods to nested group" do
          shared_examples_for("thing") do |param1|
            def foo; end
          end
          group = ExampleGroup.describe('fake group')
          shared_group = group.it_should_behave_like("thing", :a)
          shared_group.public_instance_methods.map{|m| m.to_s}.should include("foo")
        end

        it "evals the shared example group only once" do
          eval_count = 0
          shared_examples_for("thing") { |p| eval_count += 1 }
          group = ExampleGroup.describe('fake group')
          shared_group = group.it_should_behave_like("thing", :a)
          eval_count.should eq(1)
        end
      end

      context "given a block" do
        it "evaluates the block in nested group" do
          scopes = []
          shared_examples_for("thing") do
            it("gets run in the nested group") do
              scopes << self.class
            end
          end
          group = ExampleGroup.describe("group") do
            it_should_behave_like "thing" do
              it("gets run in the same nested group") do
                scopes << self.class
              end
            end
          end
          group.run

          scopes[0].should be(scopes[1])
        end
      end

      it "raises when named shared example_group can not be found" do
        group = ExampleGroup.describe("example_group")
        lambda do
          group.it_should_behave_like("a group that does not exist")
        end.should raise_error(/Could not find shared example group named/)
      end
    end

    describe "#share_as" do
      it "is exposed to the global namespace" do
        Kernel.should respond_to("share_as")
      end

      it "adds examples to current example_group using include", :compat => 'rspec-1.2' do
        share_as('Cornucopia') do
          it "is plentiful" do
            5.should eq(4)
          end
        end
        group = ExampleGroup.describe('group') { include Cornucopia }
        phantom_group = group.children.first
        phantom_group.description.should eql("")
        phantom_group.metadata[:shared_group_name].should eql('Cornucopia')
        phantom_group.examples.length.should eq(1)
        phantom_group.examples.first.metadata[:description].should eq("is plentiful")
      end
    end
  end
end
