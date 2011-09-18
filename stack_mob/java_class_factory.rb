class StackMobModel
  attr_reader :classname, :properties, :model_specific_properties

  def initialize(model_hash)
    @classname = model_hash["id"].camelize
    @properties = model_hash["properties"].map { |p| StackMobModelProperty.new(p) }
    @model_specific_properties = @properties.reject { |p| ["lastmoddate","createddate",@classname.underscore+'_id'].include?(p.name.underscore) }
  end
end

class StackMobModelProperty
  attr_reader :name, :ivar_name
  
  def initialize(property_array)
    @name = property_array.first.camelize
    @ivar_name = self.name.camelize(false)
    
    hash = property_array.last
    @type = hash["type"]
    @items = hash["items"]
  end
  
  def java_type(type = nil)
    type ||= @type
    case type
    when 'string'
      'String'
    when 'integer'
      'long'
    when 'array'
      "List<#{java_type(@items["type"])}>"
    else
      'unknownType-'+type
    end
  end
  
  def java_map_getter
    type ||= @type
    
    cast = "(#{java_type})"
    
    getter = case type
      when 'integer'
        "this.getLongValue(map, \"#{name.underscore}\")"
      else
        "map.get(\"#{name.underscore}\")"
      end
    
    "#{cast}#{getter}"
  end
end

class Binder
  def initialize(model)
    @model = model
  end
  def get_binding
    return binding()
  end
end

#############

class JavaClassFactory
  def initialize(model_hash)
    @model_hash = model_hash
  end
  
  def class_source
    begin
      File.open(File.dirname(__FILE__) + '/../templates/model.java.erb', 'r') do |f|
        contents = f.readlines.join
   
        model = StackMobModel.new(@model_hash)
        binder = Binder.new(model)
   
        template = ERB.new(contents, 0, '-')
        begin
          puts template.result(binder.get_binding)
        rescue Exception  => te
          puts "Exception in template: #{te}"
          puts te.backtrace
        end
      end
    rescue Exception => ex
      p ex
      exit
    end
  end
end