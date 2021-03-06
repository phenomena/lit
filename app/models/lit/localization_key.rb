module Lit
  class LocalizationKey < ActiveRecord::Base
    attr_accessor :interpolated_key

    ## SCOPES
    scope :completed, proc{ where(:is_completed=>true) }
    scope :not_completed, proc{ where(:is_completed=>false) }
    scope :starred, proc{ where(:is_starred=>true) }
    scope :ordered, proc{ order('localization_key asc') }

    ## ASSOCIATIONS
    has_many :localizations, :dependent=>:destroy

    ## VALIDATIONS
    validates :localization_key,
              :presence=>true,
              :uniqueness=>true

    if ::Rails::VERSION::MAJOR<4
      ## ACCESSIBLE
      attr_accessible :localization_key
    end

    def to_s
      self.localization_key
    end

    def clone_localizations
      new_created = false
      Lit::Locale.find_each do |locale|
        self.localizations.where(:locale_id=>locale.id).first_or_create do |l|
          l.default_value = interpolated_key
          new_created = true
        end
      end
      if new_created
        Lit::LocalizationKey.update_all ['is_completed=?', false], ['id=? and is_completed=?', self.id, false]
      end
    end

    def mark_completed
      self.is_completed = self.localizations.changed.count(:id) == self.localizations.count
    end

    def mark_completed!
      self.save if self.mark_completed
    end

    def mark_all_completed!
      self.localizations.update_all(['is_changed=?', true])
      mark_completed!
    end

    def self.search(options={})
      s = scoped.ordered
      if options[:key_prefix].present?
        q = "#{options[:key_prefix]}%"
        s = s.where('lit_localization_keys.localization_key like ?', q)
      end
      if options[:key].present?
        q = "%#{options[:key]}%"
        s = s.joins([:localizations]).where('lit_localization_keys.localization_key like ? or lit_localizations.default_value like ? or lit_localizations.translated_value like ?', q, q, q)
      end
      if not options[:include_completed].to_i==1
        s = s.not_completed
      end
      s
    end

  end
end
