/* SPDX-FileCopyrightText: 2023 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later */

#include "DNA_pointcloud_types.h"

#include "BKE_geometry_set.hh"
#include "BKE_lib_id.hh"
#include "BKE_pointcloud.hh"

#include "attribute_access_intern.hh"

namespace blender::bke {

/* -------------------------------------------------------------------- */
/** \name Geometry Component Implementation
 * \{ */

PointCloudComponent::PointCloudComponent() : GeometryComponent(Type::PointCloud) {}

PointCloudComponent::PointCloudComponent(PointCloud *pointcloud, GeometryOwnershipType ownership)
    : GeometryComponent(Type::PointCloud), pointcloud_(pointcloud), ownership_(ownership)
{
}

PointCloudComponent::~PointCloudComponent()
{
  this->clear();
}

GeometryComponentPtr PointCloudComponent::copy() const
{
  PointCloudComponent *new_component = new PointCloudComponent();
  if (pointcloud_ != nullptr) {
    new_component->pointcloud_ = BKE_pointcloud_copy_for_eval(pointcloud_);
    new_component->ownership_ = GeometryOwnershipType::Owned;
  }
  return GeometryComponentPtr(new_component);
}

void PointCloudComponent::clear()
{
  BLI_assert(this->is_mutable() || this->is_expired());
  if (pointcloud_ != nullptr) {
    if (ownership_ == GeometryOwnershipType::Owned) {
      BKE_id_free(nullptr, pointcloud_);
    }
    pointcloud_ = nullptr;
  }
}

bool PointCloudComponent::has_pointcloud() const
{
  return pointcloud_ != nullptr;
}

void PointCloudComponent::replace(PointCloud *pointcloud, GeometryOwnershipType ownership)
{
  BLI_assert(this->is_mutable());
  this->clear();
  pointcloud_ = pointcloud;
  ownership_ = ownership;
}

PointCloud *PointCloudComponent::release()
{
  BLI_assert(this->is_mutable());
  PointCloud *pointcloud = pointcloud_;
  pointcloud_ = nullptr;
  return pointcloud;
}

const PointCloud *PointCloudComponent::get() const
{
  return pointcloud_;
}

PointCloud *PointCloudComponent::get_for_write()
{
  BLI_assert(this->is_mutable());
  if (ownership_ == GeometryOwnershipType::ReadOnly) {
    pointcloud_ = BKE_pointcloud_copy_for_eval(pointcloud_);
    ownership_ = GeometryOwnershipType::Owned;
  }
  return pointcloud_;
}

bool PointCloudComponent::is_empty() const
{
  return pointcloud_ == nullptr;
}

bool PointCloudComponent::owns_direct_data() const
{
  return ownership_ == GeometryOwnershipType::Owned;
}

void PointCloudComponent::ensure_owns_direct_data()
{
  BLI_assert(this->is_mutable());
  if (ownership_ != GeometryOwnershipType::Owned) {
    if (pointcloud_) {
      pointcloud_ = BKE_pointcloud_copy_for_eval(pointcloud_);
    }
    ownership_ = GeometryOwnershipType::Owned;
  }
}

/** \} */

/* -------------------------------------------------------------------- */
/** \name Attribute Access
 * \{ */

static void tag_component_positions_changed(void *owner)
{
  PointCloud &points = *static_cast<PointCloud *>(owner);
  points.tag_positions_changed();
}

static void tag_component_radius_changed(void *owner)
{
  PointCloud &points = *static_cast<PointCloud *>(owner);
  points.tag_radii_changed();
}

/**
 * In this function all the attribute providers for a point cloud component are created. Most data
 * in this function is statically allocated, because it does not change over time.
 */
static ComponentAttributeProviders create_attribute_providers_for_point_cloud()
{
  static CustomDataAccessInfo point_access = {
      [](void *owner) -> CustomData * {
        PointCloud *pointcloud = static_cast<PointCloud *>(owner);
        return &pointcloud->pdata;
      },
      [](const void *owner) -> const CustomData * {
        const PointCloud *pointcloud = static_cast<const PointCloud *>(owner);
        return &pointcloud->pdata;
      },
      [](const void *owner) -> int {
        const PointCloud *pointcloud = static_cast<const PointCloud *>(owner);
        return pointcloud->totpoint;
      }};

  static BuiltinCustomDataLayerProvider position("position",
                                                 AttrDomain::Point,
                                                 CD_PROP_FLOAT3,
                                                 BuiltinAttributeProvider::NonDeletable,
                                                 point_access,
                                                 tag_component_positions_changed);
  static BuiltinCustomDataLayerProvider radius("radius",
                                               AttrDomain::Point,
                                               CD_PROP_FLOAT,
                                               BuiltinAttributeProvider::Deletable,
                                               point_access,
                                               tag_component_radius_changed);
  static BuiltinCustomDataLayerProvider id("id",
                                           AttrDomain::Point,
                                           CD_PROP_INT32,
                                           BuiltinAttributeProvider::Deletable,
                                           point_access,
                                           nullptr);
  static CustomDataAttributeProvider point_custom_data(AttrDomain::Point, point_access);
  return ComponentAttributeProviders({&position, &radius, &id}, {&point_custom_data});
}

static AttributeAccessorFunctions get_pointcloud_accessor_functions()
{
  static const ComponentAttributeProviders providers =
      create_attribute_providers_for_point_cloud();
  AttributeAccessorFunctions fn =
      attribute_accessor_functions::accessor_functions_for_providers<providers>();
  fn.domain_size = [](const void *owner, const AttrDomain domain) {
    if (owner == nullptr) {
      return 0;
    }
    const PointCloud &pointcloud = *static_cast<const PointCloud *>(owner);
    switch (domain) {
      case AttrDomain::Point:
        return pointcloud.totpoint;
      default:
        return 0;
    }
  };
  fn.domain_supported = [](const void * /*owner*/, const AttrDomain domain) {
    return domain == AttrDomain::Point;
  };
  fn.adapt_domain = [](const void * /*owner*/,
                       const GVArray &varray,
                       const AttrDomain from_domain,
                       const AttrDomain to_domain) {
    if (from_domain == to_domain && from_domain == AttrDomain::Point) {
      return varray;
    }
    return GVArray{};
  };
  return fn;
}

static const AttributeAccessorFunctions &get_pointcloud_accessor_functions_ref()
{
  static const AttributeAccessorFunctions fn = get_pointcloud_accessor_functions();
  return fn;
}

}  // namespace blender::bke

blender::bke::AttributeAccessor PointCloud::attributes() const
{
  return blender::bke::AttributeAccessor(this,
                                         blender::bke::get_pointcloud_accessor_functions_ref());
}

blender::bke::MutableAttributeAccessor PointCloud::attributes_for_write()
{
  return blender::bke::MutableAttributeAccessor(
      this, blender::bke::get_pointcloud_accessor_functions_ref());
}

namespace blender::bke {

std::optional<AttributeAccessor> PointCloudComponent::attributes() const
{
  return AttributeAccessor(pointcloud_, get_pointcloud_accessor_functions_ref());
}

std::optional<MutableAttributeAccessor> PointCloudComponent::attributes_for_write()
{
  PointCloud *pointcloud = this->get_for_write();
  return MutableAttributeAccessor(pointcloud, get_pointcloud_accessor_functions_ref());
}

/** \} */

}  // namespace blender::bke