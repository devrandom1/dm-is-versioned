module DataMapper
  module Is
    ##
    # = Is Versioned
    # The Versioned module will configure a model to be versioned.
    #
    # The is-versioned plugin functions differently from other versioning
    # solutions (such as acts_as_versioned), but can be configured to
    # function like it if you so desire.
    #
    # The biggest difference is that there is not an incrementing 'version'
    # field, but rather, any field of your choosing which will be unique
    # on update.
    #
    # == Setup
    # For simplicity, I will assume that you have loaded dm-timestamps to
    # automatically update your :updated_at field. See versioned_spec for
    # and example of updating the versioned field yourself.
    #
    #   class Story
    #     include DataMapper::Resource
    #     property :id, Serial
    #     property :title, String
    #     property :updated_at, DateTime
    #
    #     is_versioned :on => [:updated_at]
    #   end
    #
    # == Auto Upgrading and Auto Migrating
    #
    #   Story.auto_migrate! # => will run auto_migrate! on Story::Version, too
    #   Story.auto_upgrade! # => will run auto_upgrade! on Story::Version, too
    #
    # == Usage
    #
    #   story = Story.get(1)
    #   story.title = "New Title"
    #   story.save # => Saves this story and creates a new version with the
    #              #    original values.
    #   story.versions.size # => 1
    #
    #   story.title = "A Different New Title"
    #   story.save
    #   story.versions.size # => 2
    #
    # TODO: enable replacing a current version with an old version.
    module Versioned
      def is_versioned(options = {})
        @is_versioned_on = options[:on]

        extend(Migration) if respond_to?(:auto_migrate!)

        debugger
        before :save do
          puts "Fucking hell"
          debugger
          if dirty? && !new?
            @pending_version_attributes = original_attributes.dup
          end
        end

        after :save do
          debugger
          if clean? && @pending_version_attributes
            model::Version.create!(attributes.merge(@pending_version_attributes))
          end
          @pending_version_attributes = nil
        end

        extend ClassMethods
        include InstanceMethods
      end

      module ClassMethods
        def const_missing(name)
          if name == :Version
            model = DataMapper::Model.new(name, self)

            properties.each do |property|
              type = case property
                when DataMapper::Property::Discriminator then Class
                when DataMapper::Property::Serial        then Integer
              else
                property.class
              end

              options = property.options.merge(:key => property.name == @is_versioned_on)

              # Replace keys for plain indices
              options[:index] = true if options[:key]

              # these options are dangerous and break the versioning system
              [:unique, :key, :serial].each { |option| options.delete(option) }

              model.property(property.name, type, options)
            end

            model.property('is_versioned_id', DataMapper::Property::Serial, :key => true)
            model.finalize
            model
          else
            super
          end
        end
      end # ClassMethods

      module InstanceMethods
        ##
        # Returns a collection of other versions of this resource.
        # The versions are related on the models keys, and ordered
        # by the version field.
        #
        # --
        # @return <Collection>
        def versions
          version_model = model.const_get(:Version)
          query = Hash[ model.key.zip(key).map { |p, v| [ p.name, v ] } ]
          query.merge!(:order => :is_versioned_id.desc)
          version_model.all(query)
        end
      end # InstanceMethods

      module Migration

        def auto_migrate!(repository_name = self.repository_name)
          super
          self::Version.auto_migrate!
        end

        def auto_upgrade!(repository_name = self.repository_name)
          super
          self::Version.auto_upgrade!
        end

      end # Migration

    end # Versioned
  end # Is
end # DataMapper
