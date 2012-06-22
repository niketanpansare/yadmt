#ifndef MY_ASSERT_H
#define MY_ASSERT_H

#include <iostream>
#include <string>
using namespace std;

/// Usage: 
/// 1. For fatal assertions, do: ASSERT(boolean_condition) << human readable message << DIE;
/// Eg usage: ASSERT(classValue == 1 || classValue == -1) << "For 2 classes, Only values -1 and 1 should be used as class label, not " << classValue;
/// Eg output: Assertion Failed: [GenerateArffFiles.cpp:68, 'argc == 5'] Incorrect number of arguments
///
/// 2. For non-fatal assertions, do: ASSERT(boolean_condition) << human readable message;
///
/// Note: Never use this class directly, only use through macros ASSERT and DIE.
/// Also, note: this class and the related macros are not thread-safe.
class ErrorHandling {
public: 
  /// Function that help implement Singleton pattern.
  static ErrorHandling& getinstance();
  /// Overloaded functions that help print output for basic data types
  ErrorHandling& operator<<(const std::string message);
  ErrorHandling& operator<<(const int message);
  ErrorHandling& operator<<(const long message);
  ErrorHandling& operator<<(const double message);
  ErrorHandling& operator<<(const bool message);
  ErrorHandling& operator<<(const char message);
  ErrorHandling& operator<<(const short message);
  ErrorHandling& operator<<(const float message);
  ErrorHandling& operator<<(const char* message);
  
  // I know this is probably a bad idea, but makes my life a lot easy.
  bool isExpressionTrue;
private:
  // private default, copy constructor and assignment operator to implement Singleton pattern.
  ErrorHandling() {};
  ErrorHandling(ErrorHandling const&) {};
  ErrorHandling& operator=(ErrorHandling const&){};
};

#define ASSERT(bool_exp) \
{ (ErrorHandling::getinstance()).isExpressionTrue = (bool_exp); \
if( !((ErrorHandling::getinstance()).isExpressionTrue) ) \
cerr << "\nAssertion Failed: [" << __FILE__ << ":" << __LINE__ << ", \'" << #bool_exp << "\'] "; } \
(ErrorHandling::getinstance())

#define DIE "\n"; if( !((ErrorHandling::getinstance()).isExpressionTrue) ) exit(1)

#endif