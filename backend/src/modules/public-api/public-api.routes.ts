import { Router } from 'express'
import { google } from 'googleapis'
import { prisma } from '../../config/prisma.js'
import { requireApiKey } from '../../middleware/api-key.middleware.js'
import { hashToken } from '../../utils/crypto.js'
import { deleteS3Object, syncS3Quota } from '../s3/s3.service.js'
import { getAuthedGoogleClient, syncGoogleQuota } from '../google/google.service.js'
import { handleUpload } from '../uploads/upload.routes.js'

export const publicApiRouter = Router()

publicApiRouter.post('/v1/uploads', requireApiKey('files:upload'), handleUpload)

publicApiRouter.delete('/files/:code', requireApiKey('files:upload'), async (req, res, next) => {
  try {
    const code = String(req.params.code)
    const share = await prisma.fileShare.findFirst({
      where: { enabled: true, AND: [{ OR: [{ token: code }, { tokenHash: hashToken(code) }] }, { OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }] }] },
      include: { file: { include: { connectedAccount: true } } },
    })
    if (!share || share.file.status !== 'active') return res.status(404).json({ code: 'FILE_NOT_FOUND', message: 'File not found.' })

    if (share.file.provider === 's3') {
      await deleteS3Object(share.file)
      await syncS3Quota(share.file.connectedAccountId).catch(() => undefined)
    } else {
      const auth = await getAuthedGoogleClient(share.file.connectedAccount)
      const drive = google.drive({ version: 'v3', auth })
      await drive.files.delete({ fileId: share.file.providerFileId })
      await syncGoogleQuota(share.file.connectedAccountId).catch(() => undefined)
    }

    await prisma.file.delete({ where: { id: share.file.id } })
    return res.json({ status: 'ok', deleted: 1 })
  } catch (error) {
    return next(error)
  }
})
