def create_domain_class(class_name, attrs)
  clazz = Class.new do 
    def self.define_attribute(attribute)
      self.send :attr_accessor, attribute
    end
  end
  Object.const_set class_name, clazz
  attrs.each { |att| clazz.define_attribute(att)}
end
