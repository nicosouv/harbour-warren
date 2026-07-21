// Single place for all name / app-id / storage constants.
#ifndef WARREN_APPID_H
#define WARREN_APPID_H

namespace warren {
namespace AppId {

static const char* const kOrganization = "harbour-warren";
static const char* const kApplication  = "harbour-warren";
static const char* const kDisplayName  = "Warren";
static const char* const kDatabaseFile = "warren.sqlite";
static const int kSchemaVersion = 1;

} // namespace AppId
} // namespace warren

#endif // WARREN_APPID_H
