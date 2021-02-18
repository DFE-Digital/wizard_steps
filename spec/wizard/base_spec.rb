require "spec_helper"
require "wizard_steps/wizard/base"

RSpec.describe Wizard::Base do
  include_context "wizard store"

  let(:wizardclass) { TestWizard }
  let(:wizard) { wizardclass.new wizardstore, "age" }

  describe ".indexed_steps" do
    subject { wizardclass.indexed_steps }

    it do
      is_expected.to eql \
        "name" => TestWizard::Name,
        "age" => TestWizard::Age,
        "postcode" => TestWizard::Postcode
    end
  end

  describe ".step" do
    it "will return steps class for valid step" do
      expect(wizardclass.step("age")).to eql TestWizard::Age
    end

    it "will raise exception for unknown step" do
      expect { wizardclass.step("unknown") }.to \
        raise_exception(Wizard::UnknownStep)
    end
  end

  describe ".key_index" do
    it "will return index for known step" do
      expect(wizardclass.key_index("age")).to eql 1
    end

    it "will raise exception for unknown step" do
      expect { wizardclass.key_index("unknown") }.to \
        raise_exception(Wizard::UnknownStep)
    end
  end

  describe ".step_keys" do
    subject { wizardclass.step_keys }
    it { is_expected.to eql %w[name age postcode] }
  end

  describe ".first_key" do
    subject { wizardclass.first_key }
    it { is_expected.to eql "name" }
  end

  describe ".new" do
    it "should return instance for known step" do
      expect(wizardclass.new(wizardstore, "name")).to be_instance_of wizardclass
    end

    it "should raise exception for unknown step" do
      expect { wizardclass.new wizardstore, "unknown" }.to \
        raise_exception Wizard::UnknownStep
    end
  end

  describe "#can_proceed?" do
    subject { wizardclass.new(wizardstore, "name") }
    it { is_expected.to be_can_proceed }
  end

  describe "#current_key" do
    subject { wizardclass.new(wizardstore, "name").current_key }
    it { is_expected.to eql "name" }
  end

  describe "#later_keys" do
    subject { wizardclass.new(wizardstore, "name").later_keys }
    it { is_expected.to eql %w[age postcode] }
  end

  describe "#earlier_keys" do
    subject { wizardclass.new(wizardstore, "postcode").earlier_keys }
    it { is_expected.to eql %w[name age] }
  end

  describe "#find" do
    subject { wizard.find("age") }
    it { is_expected.to be_instance_of TestWizard::Age }
    it { is_expected.to have_attributes age: 35 }
  end

  describe "#find_current_step" do
    subject { wizard.find_current_step }
    it { is_expected.to be_instance_of TestWizard::Age }
  end

  describe "#previous_key" do
    context "when there are earlier steps" do
      subject { wizard.previous_key("age") }
      it { is_expected.to eql "name" }
    end

    context "when there are no earlier steps" do
      subject { wizard.previous_key("name") }
      it { is_expected.to be_nil }
    end

    context "when no key supplied" do
      subject { wizard.previous_key }
      it { is_expected.to eql "name" }
    end
  end

  describe "#next_key" do
    context "when there are more steps" do
      subject { wizard.next_key("age") }
      it { is_expected.to eql "postcode" }
    end

    context "when there are no more steps" do
      subject { wizard.next_key("postcode") }
      it { is_expected.to be_nil }
    end

    context "when no key supplied" do
      subject { wizard.next_key }
      it { is_expected.to eql "postcode" }
    end
  end

  describe "#valid?" do
    let(:backingstore) { { "age" => 30, "postcode" => "TE571NG" } }

    before do
      allow_any_instance_of(TestWizard::Name).to \
        receive(:valid?).and_return name_is_valid
    end

    subject { wizard.valid? }

    context "with all steps completed" do
      let(:name_is_valid) { true }
      it { is_expected.to be true }
    end

    context "with missing step" do
      let(:name_is_valid) { false }
      it { is_expected.to be false }
    end
  end

  describe "#complete?" do
    subject(:complete?) { wizard.complete? }

    let(:wizard) { wizardclass.new(wizardstore, step) }
    let(:backingstore) { { "name" => "My Name", "age" => 13, "postcode" => "MP11PM" } }
    let(:step) { "postcode" }

    context "when on the last step and all the data is valid" do
      it { is_expected.to be true }
    end

    context "when on the last step but not all the data are valid" do
      let(:backingstore) { { "name" => "My Name" } }

      it { is_expected.to be false }
    end

    context "when not on the last step" do
      let(:step) { "age" }

      it { is_expected.to be false }
    end
  end

  describe "#complete!" do
    class CompleteTestWizard < TestWizard
      def do_complete
        "DO_COMPLETE_RAN"
      end
    end

    let(:wizard) { CompleteTestWizard.new(wizardstore, step) }
    let(:backingstore) { { "name" => "My Name", "age" => 13, "postcode" => "MP11PM" } }
    let(:step) { "postcode" }

    before do
      allow(wizardstore).to receive(:purge!)
    end

    context "when on the last step and all the data is valid" do
      it "purges the store" do
        wizard.complete!

        expect(wizardstore).to have_received(:purge!)
      end

      it "calls the #do_result method and yields the result of its call" do
        expect { |b| wizard.complete!(&b) }.to yield_with_args("DO_COMPLETE_RAN")
      end
    end

    context "when not on the last step (or when the data is invalid)" do
      let(:step) { "age" }

      it "does not purge the store" do
        wizard.complete!

        expect(wizardstore).not_to have_received(:purge!)
      end

      it "calls does not call the #do_result method" do
        expect { |b| wizard.complete!(&b) }.not_to yield_with_args
      end
    end
  end

  describe "invalid_steps" do
    let(:backingstore) { { "age" => 30 } }
    subject { wizard.invalid_steps.map(&:key) }
    it { is_expected.to eql %w[name postcode] }
  end

  describe "first_invalid_step" do
    let(:backingstore) { { "name" => "test" } }
    subject { wizard.first_invalid_step }
    it { is_expected.to have_attributes key: "age" }
  end

  describe "skipped steps" do
    before do
      allow_any_instance_of(TestWizard::Age).to \
        receive(:skipped?).and_return true
    end

    let(:current_step) { "name" }
    subject { wizardclass.new wizardstore, current_step }

    context "for the first step" do
      it { is_expected.to have_attributes first_step?: true }
      it { is_expected.to have_attributes next_key: "postcode" }
    end

    context "for the last step" do
      let(:current_step) { "postcode" }
      it { is_expected.to have_attributes last_step?: true }
      it { is_expected.to have_attributes previous_key: "name" }
    end

    context "when last step skipped" do
      before do
        allow_any_instance_of(TestWizard::Postcode).to \
          receive(:skipped?).and_return true
      end
      it { is_expected.to have_attributes next_key: nil }
      it { is_expected.to have_attributes last_step?: true }
      it { is_expected.to have_attributes first_step?: true }
    end

    context "with invalid steps" do
      let(:backingstore) { { "name" => "test" } }
      subject { wizard.invalid_steps.map(&:key) }
      it { is_expected.to eql %w[postcode] }
    end
  end

  describe "#reviewable_answers_by_step" do
    subject { wizard.reviewable_answers_by_step }

    it { is_expected.to include TestWizard::Name => { "name" => "Joe" } }
    it { is_expected.to include TestWizard::Age => { "age" => 35 } }
    it { is_expected.to include TestWizard::Postcode => { "postcode" => nil } }

    context "with skipped step" do
      before do
        allow_any_instance_of(TestWizard::Age).to \
          receive(:skipped?).and_return true
      end

      it { is_expected.to include TestWizard::Name => { "name" => "Joe" } }
      it { is_expected.to_not include TestWizard::Age => { "age" => 35 } }
      it { is_expected.to include TestWizard::Postcode => { "postcode" => nil } }
    end
  end

  describe "#export_data" do
    subject { wizard.export_data }

    it { is_expected.to include "name" => "Joe" }
    it { is_expected.to include "age" => 35 }
    it { is_expected.to include "postcode" => nil }

    context "with skipped step" do
      before do
        allow_any_instance_of(TestWizard::Age).to \
          receive(:skipped?).and_return true
      end

      it { is_expected.to include "name" => "Joe" }
      it { is_expected.not_to include "age" }
      it { is_expected.to include "postcode" => nil }
    end
  end
end
