# If you want to debug in development, comment the BasicObject line and uncomment the Object line.
# BasicObject has no Kernel methods includes and doesn't allow pry or debug to work
#
Pbbuilder = Class.new(Object) # allows tools like pry
# Pbbuilder = Class.new(BasicObject) # does not allow pry
