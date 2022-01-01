﻿/**
 * Copyright 2005-2007 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
 * www.ortussolutions.com
 * ---
 * OWASP AntiSamy Project that provides XSS cleanup operations to ColdBox applications
 * http://www.owasp.org/index.php/Category:OWASP_AntiSamy_Project
 * http://code.google.com/p/owaspantisamy/downloads/list
 */
component singleton threadsafe {

    // DI
    property name="moduleSettings" inject="coldbox:moduleSettings:cbantisamy";
    property name="javaLoader" inject="loader@cbjavaloader";
    property name="util" inject="coldbox.system.core.util.Util";
    property name="engine" default="ADOBE";
    property name="defaultPolicy" default="basic";

    function onDIComplete() {
        if (server.coldfusion.productname eq 'Lucee') {
            variables.engine = 'LUCEE';
        } else {
            variables.defaultPolicy = '';
        }
        variables.policies = {
            // Basic Adobe/Lucee policyfile
            'basic' : moduleSettings.libPath & '/antisamy-basic.xml',
            // Load eBay policyfile
            'ebay': moduleSettings.libPath & '/antisamy-ebay.xml',
            // Load myspace policyfile
            'myspace': moduleSettings.libPath & '/antisamy-myspace.xml',
            // Load slashdot policyfile
            'slashdot': moduleSettings.libPath & '/antisamy-slashdot.xml',
            // Load tinymce policyfile
            'tinymce': moduleSettings.libPath & '/antisamy-tinymce.xml',
            // AntiSamy policyfile
            'antisamy': moduleSettings.libPath & '/antisamy-anythinggoes.xml',
            // Custom Policy
            'custom': moduleSettings.customPolicy
        };
    }

    /**
     * clean HTML from XSS scripts using the AntiSamy project. The available policies are basic, antisamy, ebay, myspace, slashdot, custom
     */
    any function clean(required HTMLData, string policyFile = variables.defaultPolicy, boolean check = false) {
        return HTMLSanitizer(argumentCollection = arguments);
    }

    /**
     * clean HTML from XSS scripts using the AntiSamy project. The available policies are basic, antisamy, ebay, myspace, slashdot, custom
     * @HTMLData The html data to clean
     * @policyFile The policy file to use, by default it uses the basic policy file
     * @check By default it just returns the cleaned HTML, but if this is true, it will return the a boolean as to whether the HTML is safe.
     *
     * @return HTMl data or boolean from check
     */
    any function HTMLSanitizer(
        required HTMLData,
        string policyFile = variables.defaultPolicy,
        boolean check = false
    ) {
        if( !variables.policies.keyExists( arguments.policyfile ) ){
            throw(
                type='cbantisamy.AntiSamy.InvalidPolicyFile',
                message='The policy specified, #arguments.policyFile#, does not exist. Valid policies are #variables.policies.keyArray().toList()#'
            );
        }
        if ( engine == 'ADOBE' ) {
            if ( arguments.check ) {
                return isSafeHTML(
                    arguments.htmlData,
                    len(arguments.policyFile) ? variables.policies[arguments.policyFile] : javacast('null', 0)
                );
            } else {
                return getSafeHTML(
                    arguments.htmlData,
                    len( arguments.policyFile ) ? variables.policies[arguments.policyFile] : javacast('null', 0)
                );
            }
        } else {
            var _thread = createObject('java', 'java.lang.Thread');
            var currentClassloader = _thread.currentThread().getContextClassLoader();

            try {
                // Overide due to class cast exceptions
                _thread.currentThread().setContextClassLoader(javaloader.getURLClassLoader());

                // you can use any xml, our your own customised policy xml
                var antiSamy = javaLoader.create('org.owasp.validator.html.AntiSamy');

                // validate policy file
                if (NOT structKeyExists(variables.policies, arguments.policyFile)) {
                    throw(
                        message = 'Invalid Policy File: #arguments.policyFile#',
                        detail = 'The available policy files are #structKeyList(variables.policies)#',
                        type = 'AntiSamy.InvalidPolicyException'
                    );
                }

                // Clean with policy
                var cleanResult = antiSamy.scan(arguments.htmlData, variables.policies[arguments.policyFile]);

                // returning results object or just checking?
                if (arguments.check) {
                    return ! cleanResult.getNumberOfErrors();
                }

                return cleanResult.getCleanHTML();
            } catch (any e) {
                rethrow;
            } finally {
                /*
					We have to reset the classloader, due to
					thread pooling.
				*/
                _thread.currentThread().setContextClassLoader(currentClassloader);
            }
        }
    }

}
