#include "Assert.h"

ErrorHandling& ErrorHandling :: operator<<(const std::string message)  { if(!isExpressionTrue) cerr << message; return *this; }
ErrorHandling& ErrorHandling :: operator<<(const int message)          { if(!isExpressionTrue) cerr << message; return *this; }
ErrorHandling& ErrorHandling :: operator<<(const long message)         { if(!isExpressionTrue) cerr << message; return *this; }
ErrorHandling& ErrorHandling :: operator<<(const double message)       { if(!isExpressionTrue) cerr << message; return *this; }
ErrorHandling& ErrorHandling :: operator<<(const bool message)         { if(!isExpressionTrue) cerr << message; return *this; }
ErrorHandling& ErrorHandling :: operator<<(const char message)         { if(!isExpressionTrue) cerr << message; return *this; }
ErrorHandling& ErrorHandling :: operator<<(const short message)        { if(!isExpressionTrue) cerr << message; return *this; }
ErrorHandling& ErrorHandling :: operator<<(const float message)        { if(!isExpressionTrue) cerr << message; return *this; }
ErrorHandling& ErrorHandling :: operator<<(const char* message)        { if(!isExpressionTrue) cerr << message; return *this; }

ErrorHandling& ErrorHandling :: getinstance() {
  // To make this class thread-safe, add mutex here and instead on having 1 object have n objects to reduce contention.
  
  // This is a key to Singleton pattern without dynamic memory allocation
  // This instance is created only once since it is static
  static ErrorHandling instance;
  return instance;
}
