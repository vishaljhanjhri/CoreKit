Pod::Spec.new do |spec|

  spec.name         = "CoreKit"
  spec.version      = "0.0.1"
  spec.summary      = "Basic need for iOS"

  spec.description  = "Basic need for iOS"

  spec.homepage     = "https://github.com/vishaljhanjhri"
  spec.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  spec.author       = { "vishal" => "jhanjhri.vishal@gmail.com" }
  spec.source       = { :git => "https://github.com/vishaljhanjhri/CoreKit", :tag => "#{spec.version}" }

  spec.source_files  = "Classes", "CoreKit/**/*.{h,m,swift}"
  spec.exclude_files = "Classes/Exclude"
  spec.requires_arc = true

end
