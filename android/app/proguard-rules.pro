# Rhino's JavaBeans converters are optional and reference desktop-only APIs
# absent from Android. Keep R8 enabled; suppress only these missing types.
-dontwarn java.beans.BeanDescriptor
-dontwarn java.beans.BeanInfo
-dontwarn java.beans.IntrospectionException
-dontwarn java.beans.Introspector
-dontwarn java.beans.PropertyDescriptor
