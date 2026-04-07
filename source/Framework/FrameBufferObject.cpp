#include "FrameBufferObject.h"
#include "Graphics.h"
#include "../Platform/S3ECompat.h"

//======================================================================================================================
FrameBufferObject::FrameBufferObject(int width, int height, GLenum format, GLenum type)
{
    m_Width = width;
    m_Height = height;
    mPreviousFBO = 0;

    // Save current bindings before touching the FBO state.
    // On iOS, SDL2 uses a non-zero framebuffer for the screen — restoring to 0
    // would cause a black screen. Always save/restore to be safe on all platforms.
    GLint prevFBO = 0, prevRBO = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFBO);
    glGetIntegerv(GL_RENDERBUFFER_BINDING, &prevRBO);

    // Generate a texture for the frame buffer
    glGenTextures(1, &m_Tex);
    glBindTexture(GL_TEXTURE_2D, m_Tex);

    // Disable mipmapping
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    // Reserve storage
    glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, type, 0);
    glBindTexture(GL_TEXTURE_2D, 0);

    // Use the framebuffer extension to create a framebuffer object.
    glGenFramebuffers(1, &m_FBO);

    // Generate a depth buffer as a render buffer
    glGenRenderbuffers(1, &m_Depth);
    glBindRenderbuffer(GL_RENDERBUFFER, m_Depth);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);

    // Bind both to the frame buffer
    glBindFramebuffer(GL_FRAMEBUFFER, m_FBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_Tex, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, m_Depth);

    // Check the frame buffer for completeness
    IwAssert(Rowlhouse, glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

    // Restore previous bindings (critical on iOS where SDL uses framebuffer != 0)
    glBindFramebuffer(GL_FRAMEBUFFER, prevFBO);
    glBindRenderbuffer(GL_RENDERBUFFER, prevRBO);
}

//======================================================================================================================
FrameBufferObject::~FrameBufferObject()
{
    // Clear up GL objects
    glDeleteTextures(1, &m_Tex);
    glDeleteFramebuffers(1, &m_FBO);
    glDeleteRenderbuffers(1, &m_Depth);
}

//======================================================================================================================
void FrameBufferObject::Bind()
{
    // Save currently bound FBO so we can restore it in Release()
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &mPreviousFBO);

    glBindFramebuffer(GL_FRAMEBUFFER, m_FBO);

    // Must set viewport to framebuffer dimensions
    glGetIntegerv( GL_VIEWPORT, &mOrigViewport[0] );
    glViewport(0, 0, m_Width, m_Height);
}

//======================================================================================================================
void FrameBufferObject::Release()
{
    // Restore previously bound FBO (allows nested FBO usage, e.g. shadows in VR)
    glBindFramebuffer(GL_FRAMEBUFFER, mPreviousFBO);
    glViewport(mOrigViewport[0], mOrigViewport[1], mOrigViewport[2], mOrigViewport[3]);
}
