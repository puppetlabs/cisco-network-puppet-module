###############################################################################
# Copyright (c) 2016 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################
#
# See README-develop-beaker-scripts.md (Section: Test Script Variable Reference)
# for information regarding:
#  - test script general prequisites
#  - command return codes
#  - A description of the 'tests' hash and its usage
#
###############################################################################
require File.expand_path('../../lib/utilitylib.rb', __FILE__)

# Test hash top-level keys
tests = {
  master:        master,
  agent:         agent,
  resource_name: 'cisco_vrf_af',
}

# Test hash test cases
tests[:default] = {
  desc:           'Default Properties, vrf-af',
  title_pattern:  'blue ipv4 unicast',
  manifest_props: {
    route_target_both_auto:      'default',
    route_target_both_auto_evpn: 'default',
    route_target_both_auto_mvpn: 'default',
    route_target_import:         'default',
    route_target_import_evpn:    'default',
    route_target_import_mvpn:    'default',
    route_target_export:         'default',
    route_target_export_evpn:    'default',
    route_target_export_mvpn:    'default',
  },
  resource:       {
    'route_target_both_auto'      => 'false',
    'route_target_both_auto_evpn' => 'false',
    'route_target_both_auto_mvpn' => 'false',
  },
}

routetargetimport          = ['1.1.1.1:55', '1:33']
routetargetimportevpn      = ['2.2.2.2:55', '2:33']
routetargetimportmvpn      = ['7.7.7.7:55', '7:33']
routetargetimportstitching = ['5.5.5.5:55', '5:33']
routetargetexport          = ['3.3.3.3:55', '3:33']
routetargetexportevpn      = ['4.4.4.4:55', '4:33']
routetargetexportmvpn      = ['8.8.8.8:55', '8:33']
routetargetexportstitching = ['6.6.6.6:55', '6:33']
tests[:non_default] = {
  desc:           'Non Default Properties, vrf-af',
  title_pattern:  'blue ipv4 unicast',
  manifest_props: {
    route_policy_export:           'abc',
    route_policy_import:           'abc',
    route_target_both_auto:        true,
    route_target_both_auto_evpn:   true,
    route_target_both_auto_mvpn:   true,
    route_target_import:           routetargetimport,
    route_target_import_evpn:      routetargetimportevpn,
    route_target_import_mvpn:      routetargetimportmvpn,
    route_target_import_stitching: routetargetimportstitching,
    route_target_export:           routetargetexport,
    route_target_export_evpn:      routetargetexportevpn,
    route_target_export_mvpn:      routetargetexportmvpn,
    route_target_export_stitching: routetargetexportstitching,
  },
}

tests[:title_patterns_1] = {
  desc:           'T.1 Title Pattern',
  title_pattern:  'new_york',
  title_params:   { vrf: 'red', afi: 'ipv4', safi: 'unicast' },
  manifest_props: {},
  resource:       { 'ensure' => 'present' },
}

tests[:title_patterns_2] = {
  desc:          'T.2 Title Pattern',
  title_pattern: 'blue',
  title_params:  { afi: 'ipv4', safi: 'unicast' },
  resource:      { 'ensure' => 'present' },
}

tests[:title_patterns_3] = {
  desc:          'T.3 Title Pattern',
  title_pattern: 'cyan ipv4',
  title_params:  { safi: 'unicast' },
  resource:      { 'ensure' => 'present' },
}

# class to contain the test_dependencies specific to this test case
class TestVrfAf < BaseHarness
  def self.unsupported_properties(ctx, _tests, _id)
    unprops = []
    if ctx.operating_system == 'nexus'
      unprops <<
        :route_target_export_stitching <<
        :route_target_import_stitching

      if ctx.platform[/n3k$/]
        unprops <<
          :route_target_both_auto <<
          :route_target_both_auto_evpn <<
          :route_target_export_evpn <<
          :route_target_import_evpn
      end

      if ctx.platform[/n9k(-ex)?$/]
        if ctx.image?[/I[2-6]/]
          unprops <<
            :route_target_both_auto_mvpn <<
            :route_target_export_mvpn <<
            :route_target_import_mvpn
        end
      else
        unprops <<
          :route_target_both_auto_mvpn <<
          :route_target_export_mvpn <<
          :route_target_import_mvpn
      end

    else
      unprops <<
        :route_target_both_auto <<
        :route_target_both_auto_evpn <<
        :route_target_export_evpn <<
        :route_target_import_evpn

    end
    unprops
  end

  def self.dependency_manifest(ctx, tests, id)
    if ctx.operating_system == 'nexus'
      return unless id[/non_default/]
      dep = %(
        cisco_command_config { 'policy_config':
          command => 'route-map abc permit 10'
        } )
    else
      t = ctx.puppet_resource_title_pattern_munge(tests, id)
      dep = %(
        cisco_vrf { '#{t[:vrf]}': ensure => present }
        cisco_command_config { 'policy_config':
          command => '
            route-policy abc
              end-policy'
        } )
    end
    ctx.logger.info("\n  * dependency_manifest\n#{dep}")
    dep
  end
end

#################################################################
# TEST CASE EXECUTION
#################################################################
test_name "TestCase :: #{tests[:resource_name]}" do
  teardown do
    remove_all_vrfs(agent)
    vdc_limit_f3_no_intf_needed(:clear)
  end
  remove_all_vrfs(agent)
  vdc_limit_f3_no_intf_needed(:set)

  # -------------------------------------------------------------------
  logger.info("\n#{'-' * 60}\nSection 1. Default Property Testing")
  id = :default
  test_harness_run(tests, id, harness_class: TestVrfAf)

  tests[id][:ensure] = :absent
  tests[id].delete(:preclean)
  test_harness_run(tests, id, harness_class: TestVrfAf)

  # -------------------------------------------------------------------
  logger.info("\n#{'-' * 60}\nSection 2. Non Default Property Testing")
  test_harness_run(tests, :non_default, harness_class: TestVrfAf)

  # -------------------------------------------------------------------
  logger.info("\n#{'-' * 60}\nSection 3. Title Pattern Testing")
  remove_all_vrfs(agent)
  test_harness_run(tests, :title_patterns_1, harness_class: TestVrfAf)
  test_harness_run(tests, :title_patterns_2, harness_class: TestVrfAf)
  test_harness_run(tests, :title_patterns_3, harness_class: TestVrfAf)

  # -----------------------------------
  skipped_tests_summary(tests)
end
logger.info("TestCase :: #{tests[:resource_name]} :: End")
