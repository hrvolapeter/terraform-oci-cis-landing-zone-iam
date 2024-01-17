# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
data "oci_identity_domain" "idp_domain" {
  for_each = (var.identity_domain_identity_providers_configuration != null ) ? (var.identity_domain_identity_providers_configuration["identity_providers"] != null ? var.identity_domain_identity_providers_configuration["identity_providers"] : {}) : {}
    domain_id = each.value.identity_domain_id != null ? each.value.identity_domain_id : var.identity_domain_identity_providers_configuration.default_identity_domain_id
}

locals {
  nameid_formats = ["saml-emailaddress", "saml-x509", "saml-kerberos", "saml-persistent", "saml-transient", "saml-unspecified", "saml-windowsnamequalifier","saml-none"]
  user_mapping_methods = ["NameIDToUserAttribute", "AssertionAttributeToUserAttribute","CorrelationPolicyRule"]

}

resource "oci_identity_domains_identity_provider" "these" {
  for_each       = var.identity_domain_identity_providers_configuration.identity_providers != null ? var.identity_domain_identity_providers_configuration.identity_providers : {}
    lifecycle {
      ## Check 1: Valid Name ID formats.
      precondition {
        condition = each.value.name_id_format != null ? contains(local.nameid_formats, each.value.name_id_format) : true
        error_message = "VALIDATION FAILURE in identity provider \"${each.key}\": invalid value for \"name_id_format\" attribute. Valid values are ${join(",",local.nameid_formats)}."
      }
      ## Check 2: Valid User Mapping methods.
      precondition {
        condition = each.value.user_mapping_method != null ? contains(local.user_mapping_methods, each.value.user_mapping_method) : true
        error_message = "VALIDATION FAILURE in identity provider \"${each.key}\": invalid value for \"user_mapping_method\" attribute. Valid values are ${join(",",local.user_mapping_methods)}."
      }

    } 

    idcs_endpoint = contains(keys(oci_identity_domain.these),coalesce(each.value.identity_domain_id,"None")) ? oci_identity_domain.these[each.value.identity_domain_id].url : (contains(keys(oci_identity_domain.these),coalesce(var.identity_domain_identity_providers_configuration.default_identity_domain_id,"None") ) ? oci_identity_domain.these[var.identity_domain_identity_providers_configuration.default_identity_domain_id].url : data.oci_identity_domain.idp_domain[each.key].url)
  
    partner_name                        = each.value.name
    enabled                             = each.value.enabled
    schemas                             = ["urn:ietf:params:scim:schemas:oracle:idcs:IdentityProvider"]
    description                         = each.value.description
    signature_hash_algorithm            = each.value.signature_hash_algorithm
    include_signing_cert_in_signature   = each.value.send_signing_certificate
    name_id_format                      = each.value.name_id_format
    user_mapping_method                 = each.value.user_mapping_method
    user_mapping_store_attribute        = each.value.user_mapping_store_attribute
    metadata                            = file(each.value.idp_metadata_file)


   #OCI Tags not supported
}