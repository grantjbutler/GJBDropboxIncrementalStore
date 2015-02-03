Pod::Spec.new do |s|
  s.name             = "GJBDropboxIncrementalStore"
  s.version          = "0.1.0"
  s.summary          = "A short description of GJBDropboxIncrementalStore."
  s.description      = <<-DESC
                       An optional longer description of GJBDropboxIncrementalStore

                       * Markdown format.
                       * Don't worry about the indent, we strip it!
                       DESC
  s.homepage         = "https://github.com/grantjbutler/GJBDropboxIncrementalStore"
  s.license          = 'MIT'
  s.author           = "Grant J. Butler"
  s.source           = { :git => "https://github.com/grantjbutler/GJBDropboxIncrementalStore.git", :tag => s.version.to_s }

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes'

  s.dependency 'Dropbox-Sync-API-SDK', '~> 3.1'
  
  s.xcconfig = { 'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/Dropbox-Sync-API-SDK/**' }  
end
