#
# Put your custom functions in this class in order to keep the files under lib untainted
#
# This class has access to all of the stuff in deploy/lib/server_config.rb
#
class ServerConfig
    alias_method :original_deploy_src, :deploy_src
    alias_method :original_deploy_rest, :deploy_rest
    alias_method :original_deploy_ext, :deploy_ext
    alias_method :original_deploy_transform, :deploy_transform
    alias_method :original_deploy_modules, :deploy_modules
    def switch_to_user(user)
        auth_method = @properties["ml.authentication-method"]
        if (auth_method == "application-level") then
            @logger.info("Switch to user #{user}")
            r = execute_query(%Q{
                xquery version "1.0-ml";
                
                import module namespace admin="http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
                
                let $config := admin:get-configuration()
                let $config :=
                    admin:appserver-set-default-user($config,
                        xdmp:server("#{@properties["ml.app-name"]}"),
                        xdmp:user("#{user}"))
                return admin:save-configuration-without-restart($config)
            },
            :app_name => @properties["ml.app_name"]
            )
        end
    end
    
    def switch_to_rewriter(rewriter)
        auth_method = @properties["ml.authentication-method"]
        if (auth_method == "application-level") then
            @logger.info("Switch to rewriter #{rewriter}")
            r = execute_query(%Q{
                xquery version "1.0-ml";
                
                import module namespace admin="http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
                
                let $config := admin:get-configuration()
                let $config :=
                    admin:appserver-set-url-rewriter($config,
                        xdmp:server("#{@properties["ml.app-name"]}"),
                        "#{rewriter}")
                return admin:save-configuration-without-restart($config)
            },
            :app_name => @properties["ml.app_name"]
            )
        end
    end
 
    def deploy_src()
        original_deploy_src
    end
    
    def deploy_rest()
        switch_to_user(@properties["ml.user"])
        switch_to_rewriter(@properties["ml.url-rewriter"])
        original_deploy_rest
        switch_to_rewriter(@properties["ml.spec-url-rewriter"])
        switch_to_user(@properties["ml.default-user"])
    end
    
    def deploy_ext()
        switch_to_user(@properties["ml.user"])
        switch_to_rewriter(@properties["ml.url-rewriter"])
        original_deploy_ext
        switch_to_rewriter(@properties["ml.spec-url-rewriter"])
        switch_to_user(@properties["ml.default-user"])
    end
    
    def deploy_transform()
        switch_to_user(@properties["ml.user"])
        switch_to_rewriter(@properties["ml.url-rewriter"])
        original_deploy_transform
        switch_to_rewriter(@properties["ml.spec-url-rewriter"])
        switch_to_user(@properties["ml.default-user"])
    end

    def deploy_modules()
        original_deploy_modules
    end
end