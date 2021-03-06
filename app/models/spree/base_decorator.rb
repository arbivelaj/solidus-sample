module Spree::BaseDecorator
  def self.prepended(base)
    base.class_eval do
      before_create :set_token
      before_update :restore_changes
      default_scope { where(sample_indicator_id: [nil, Current.token].uniq) }

      # Set the sample data attributes to equal the changed data
      after_find do |user|
        sample_changes = find_sample_changes
        self.attributes = sample_changes.changed_data if sample_changes
      end
    end
  end

  def set_token
    self.sample_indicator_id = Current.token
  end

  # Apply changes to the changeable object instead of the sample object
  def restore_changes
    return unless Current.token # skip this when working in global mode
    return if sample_indicator_id? # skip if the current record is not global
    return unless changes.any? # no need to do anything if no changes are happening

    sample_changes = find_sample_changes || Spree::SampleChanges.new(changeable: self)
    sample_changes.changed_data = attributes

    # This method on Stores does not play well with this ActiveRecord hackery
    sample_changes.changed_data.delete("available_locales")
    sample_changes.save!

    # Mark changes as already applied so the original object is unaffected
    changes_applied
  end

  def destroy!
    super if sample_indicator_id?
  end

  private

  def find_sample_changes
    Spree::SampleChanges.find_by(changeable: self)
  end
end

Spree::Base.prepend Spree::BaseDecorator
