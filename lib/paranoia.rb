module Paranoia
  mattr_accessor :default_scope_enabled
  @@default_scope_enabled = true

  def self.without_scoping
    self.default_scope_enabled = false
    yield
  ensure
    self.default_scope_enabled = true
  end

  def self.included(klazz)
    klazz.extend Query
  end

  module Query
    def paranoid? ; true ; end

    def only_deleted
      unscoped {
        where("deleted_at is not null")
      }
    end
  end

  def destroy
    _run_destroy_callbacks { delete }
  end

  def delete
    update_attribute_or_column(:deleted_at, Time.now) if !deleted? && persisted?
    freeze
  end

  def restore!
    update_attribute_or_column :deleted_at, nil
  end

  def destroyed?
    !self.deleted_at.nil?
  end
  alias :deleted? :destroyed?

  private

  # Rails 3.1 adds update_column. Rails > 3.2.6 deprecates update_attribute, gone in Rails 4.
  def update_attribute_or_column(*args)
    respond_to?(:update_column) ? update_column(*args) : update_attribute(*args)
  end
end

class ActiveRecord::Base
  def self.acts_as_paranoid
    alias :destroy! :destroy
    alias :delete!  :delete
    include Paranoia
    default_scope do
      if Paranoia.default_scope_enabled
        where(deleted_at: nil)
      else
        unscoped
      end
    end
    scope :at, lambda { |time| where("created_at <= ?", time).where("deleted_at is null OR deleted_at >= ?", time) }
  end

  def self.paranoid? ; false ; end
  def paranoid? ; self.class.paranoid? ; end

  # Override the persisted method to allow for the paranoia gem.
  # If a paranoid record is selected, then we only want to check
  # if it's a new record, not if it is "destroyed".
  def persisted?
    paranoid? ? !new_record? : super
  end
end
