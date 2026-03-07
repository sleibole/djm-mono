Gem::Specification.new do |spec|
  spec.name          = "djm_jwt"
  spec.version       = "0.1.0"
  spec.authors       = ["DJMagic.io"]
  spec.summary       = "JWT generation and validation for DJMagic.io services"

  spec.files         = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.add_dependency "jwt"
end
