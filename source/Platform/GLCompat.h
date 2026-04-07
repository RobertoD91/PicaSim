#pragma once

// Platform OpenGL header compatibility shim for Apple platforms.
// Pre-included via CMake -include flag on our targets only (Framework, Platform,
// Heightfield, PicaSim). Must NOT be applied to third-party targets like ImGui
// or SDL2 whose own loaders conflict with Apple's gl.h.

#ifdef __APPLE__
  #include <TargetConditionals.h>

  #if TARGET_OS_IPHONE
    // iOS/iPadOS: OpenGL ES 2.0
    #include <OpenGLES/ES2/gl.h>
    #include <OpenGLES/ES2/glext.h>
  #else
    // macOS: legacy OpenGL 2.1 (system framework, not Brew Mesa)
    #include <OpenGL/gl.h>
    #include <OpenGL/glext.h>
  #endif

  // Map OES extension names to core equivalents (used throughout the codebase)
  #ifndef GL_FRAMEBUFFER_OES
    #define GL_FRAMEBUFFER_OES  GL_FRAMEBUFFER
  #endif
  #ifndef GL_RENDERBUFFER_OES
    #define GL_RENDERBUFFER_OES GL_RENDERBUFFER
  #endif
  #ifndef GL_DEPTH_ATTACHMENT_OES
    #define GL_DEPTH_ATTACHMENT_OES GL_DEPTH_ATTACHMENT
  #endif
  #ifndef glFramebufferRenderbufferOES
    #define glFramebufferRenderbufferOES glFramebufferRenderbuffer
  #endif

  // GLES2 uniform-limit constants missing from macOS gl.h (present on iOS/Android)
  #if !TARGET_OS_IPHONE
    #ifndef GL_MAX_VERTEX_UNIFORM_VECTORS
      #define GL_MAX_VERTEX_UNIFORM_VECTORS   0x8DFB
    #endif
    #ifndef GL_MAX_VARYING_VECTORS
      #define GL_MAX_VARYING_VECTORS          0x8DFC
    #endif
    #ifndef GL_MAX_FRAGMENT_UNIFORM_VECTORS
      #define GL_MAX_FRAGMENT_UNIFORM_VECTORS 0x8DFD
    #endif
  #endif
#endif
