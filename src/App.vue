<template>
  <div class="container">
    <div class="header">
      <h1>🔧 批量图片去水印工具</h1>
      <p>纯前端处理 · 安全高效 · 批量操作</p>
    </div>

    <div class="main-content">
      <div class="sidebar">
        <div 
          class="upload-area" 
          :class="{ dragover: isDragover }"
          @click="triggerFileInput"
          @dragover.prevent="isDragover = true"
          @dragleave="isDragover = false"
          @drop.prevent="handleDrop"
        >
          <svg viewBox="0 0 24 24">
            <path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM14 13v4h-4v-4H7l5-5 5 5h-3z"/>
          </svg>
          <p>拖拽图片到此处或点击上传</p>
          <p style="font-size: 0.8em; margin-top: 5px;">支持 JPG、PNG 格式</p>
        </div>
        <input 
          type="file" 
          class="file-input" 
          ref="fileInput"
          multiple 
          accept=".jpg,.jpeg,.png"
          @change="handleFileChange"
        />

        <div class="stats" v-if="images.length > 0">
          已选择 <span>{{ images.length }}</span> 张图片
        </div>

        <div class="image-list">
          <div v-if="images.length === 0" class="empty-state">
            <p>暂无图片</p>
          </div>
          <div 
            v-for="(image, index) in images" 
            :key="index"
            class="image-item"
            :class="{ active: currentIndex === index }"
            @click="selectImage(index)"
          >
            <img :src="image.dataUrl" :alt="image.name" />
            <div class="info">
              <div class="name">{{ image.name }}</div>
              <div class="size">{{ (image.size / 1024).toFixed(1) }} KB</div>
            </div>
            <span class="remove" @click.stop="removeImage(index)">&times;</span>
          </div>
        </div>

        <div class="controls">
          <button 
            class="btn btn-primary" 
            :disabled="!canProcess"
            @click="processCurrentImage"
          >
            🔍 去除水印
          </button>
          <button 
            class="btn btn-secondary" 
            :disabled="!canDownloadSingle"
            @click="downloadCurrentImage"
          >
            💾 下载当前图片
          </button>
          <button 
            class="btn btn-secondary" 
            :disabled="!canDownloadZip"
            @click="downloadAllAsZip"
          >
            📦 打包下载 ZIP
          </button>
          <button 
            class="btn btn-danger" 
            @click="clearAll"
          >
            🗑️ 清空所有
          </button>
        </div>
      </div>

      <div class="canvas-container">
        <div class="canvas-wrapper" ref="canvasWrapper" @mousedown="handleCanvasMouseDown">
          <canvas ref="mainCanvas"></canvas>
          <div 
            class="selection-box" 
            ref="selectionBox"
            :style="selectionStyle"
          >
            <div class="resize-handle nw" @mousedown.stop="startResize('nw')"></div>
            <div class="resize-handle ne" @mousedown.stop="startResize('ne')"></div>
            <div class="resize-handle sw" @mousedown.stop="startResize('sw')"></div>
            <div class="resize-handle se" @mousedown.stop="startResize('se')"></div>
          </div>
        </div>

        <div class="instructions">
          <h3>📋 使用说明</h3>
          <ul>
            <li>拖拽或点击上传多张图片</li>
            <li>点击左侧图片列表切换图片</li>
            <li>在图片上拖动鼠标创建选区框</li>
            <li>拖动选区框调整位置，拖动角点调整大小</li>
            <li>点击"去除水印"按钮处理图片</li>
            <li>支持单张下载或打包为ZIP下载</li>
          </ul>
        </div>
      </div>
    </div>

    <div class="loading" :class="{ show: isLoading }">
      <div class="loading-spinner"></div>
      <div class="loading-text">{{ loadingText }}</div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import JSZip from 'jszip'

const images = ref([])
const currentIndex = ref(-1)
const isDragover = ref(false)
const isLoading = ref(false)
const loadingText = ref('处理中...')

const fileInput = ref(null)
const canvasWrapper = ref(null)
const mainCanvas = ref(null)
const selectionBox = ref(null)

const isDrawing = ref(false)
const isDragging = ref(false)
const isResizing = ref(false)
const resizeDirection = ref('')
const dragOffset = ref({ x: 0, y: 0 })
const startPoint = ref({ x: 0, y: 0 })
const initialBox = ref({ left: 0, top: 0, width: 0, height: 0 })

const selection = ref({
  left: 0,
  top: 0,
  width: 0,
  height: 0,
  visible: false
})

const currentImage = computed(() => {
  return currentIndex.value >= 0 ? images.value[currentIndex.value] : null
})

const canProcess = computed(() => {
  return currentImage.value && selection.value.visible && 
         selection.value.width > 10 && selection.value.height > 10
})

const canDownloadSingle = computed(() => {
  return currentImage.value && currentImage.value.processed
})

const canDownloadZip = computed(() => {
  return images.value.some(img => img.processed)
})

const selectionStyle = computed(() => {
  return {
    display: selection.value.visible ? 'block' : 'none',
    left: selection.value.left + 'px',
    top: selection.value.top + 'px',
    width: selection.value.width + 'px',
    height: selection.value.height + 'px'
  }
})

const triggerFileInput = () => {
  fileInput.value?.click()
}

const handleFileChange = (event) => {
  const files = event.target.files
  if (files.length > 0) {
    processFiles(Array.from(files))
  }
  event.target.value = ''
}

const handleDrop = (event) => {
  isDragover.value = false
  const files = event.dataTransfer.files
  if (files.length > 0) {
    processFiles(Array.from(files))
  }
}

const processFiles = async (files) => {
  const validTypes = ['image/jpeg', 'image/jpg', 'image/png']
  const validFiles = files.filter(file => validTypes.includes(file.type))

  for (const file of validFiles) {
    const reader = new FileReader()
    await new Promise((resolve) => {
      reader.onload = (e) => {
        const img = new Image()
        img.onload = () => {
          images.value.push({
            name: file.name,
            size: file.size,
            type: file.type,
            dataUrl: e.target.result,
            image: img,
            processed: false,
            processedDataUrl: null
          })
          if (images.value.length === 1) {
            selectImage(0)
          }
          resolve()
        }
        img.src = e.target.result
      }
      reader.readAsDataURL(file)
    })
  }
}

const selectImage = async (index) => {
  currentIndex.value = index
  selection.value.visible = false
  await displayOriginalImage(images.value[index])
}

const removeImage = (index) => {
  images.value.splice(index, 1)
  if (currentIndex.value >= images.value.length) {
    currentIndex.value = images.value.length - 1
  }
  if (currentImage.value) {
    displayOriginalImage(currentImage.value)
  } else {
    const canvas = mainCanvas.value
    if (canvas) {
      canvas.width = 0
      canvas.height = 0
    }
    selection.value.visible = false
  }
}

const clearAll = () => {
  images.value = []
  currentIndex.value = -1
  const canvas = mainCanvas.value
  if (canvas) {
    canvas.width = 0
    canvas.height = 0
  }
  selection.value.visible = false
}

const displayOriginalImage = async (imageData) => {
  await nextTick()
  const canvas = mainCanvas.value
  if (!canvas || !imageData) return

  const ctx = canvas.getContext('2d')
  const maxWidth = 800
  const maxHeight = 600
  let width = imageData.image.width
  let height = imageData.image.height

  if (width > maxWidth) {
    height = (maxWidth / width) * height
    width = maxWidth
  }
  if (height > maxHeight) {
    width = (maxHeight / height) * width
    height = maxHeight
  }

  canvas.width = width
  canvas.height = height
  ctx.drawImage(imageData.image, 0, 0, width, height)
}

const displayProcessedImage = (imageData) => {
  const img = new Image()
  img.onload = () => {
    const canvas = mainCanvas.value
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    const maxWidth = 800
    const maxHeight = 600
    let width = img.width
    let height = img.height

    if (width > maxWidth) {
      height = (maxWidth / width) * height
      width = maxWidth
    }
    if (height > maxHeight) {
      width = (maxHeight / height) * width
      height = maxHeight
    }

    canvas.width = width
    canvas.height = height
    ctx.drawImage(img, 0, 0, width, height)
  }
  img.src = imageData.processedDataUrl
}

const handleCanvasMouseDown = (e) => {
  if (!currentImage.value) return

  const rect = canvasWrapper.value.getBoundingClientRect()
  const x = e.clientX - rect.left
  const y = e.clientY - rect.top

  const selBox = selection.value
  if (x >= selBox.left && x <= selBox.left + selBox.width &&
      y >= selBox.top && y <= selBox.top + selBox.height) {
    isDragging.value = true
    dragOffset.value = { x: x - selBox.left, y: y - selBox.top }
    return
  }

  isDrawing.value = true
  startPoint.value = { x, y }
  selection.value = {
    left: x,
    top: y,
    width: 0,
    height: 0,
    visible: true
  }
}

const startResize = (direction) => {
  isResizing.value = true
  resizeDirection.value = direction
  startPoint.value = {
    x: selection.value.left,
    y: selection.value.top
  }
  initialBox.value = { ...selection.value }
}

const handleMouseMove = (e) => {
  if (!canvasWrapper.value) return

  const rect = canvasWrapper.value.getBoundingClientRect()
  const x = e.clientX - rect.left
  const y = e.clientY - rect.top

  if (isDrawing.value) {
    const width = Math.abs(x - startPoint.value.x)
    const height = Math.abs(y - startPoint.value.y)
    const left = Math.min(x, startPoint.value.x)
    const top = Math.min(y, startPoint.value.y)

    selection.value = {
      ...selection.value,
      left,
      top,
      width,
      height
    }
  }

  if (isDragging.value) {
    const newLeft = x - dragOffset.value.x
    const newTop = y - dragOffset.value.y

    selection.value = {
      ...selection.value,
      left: Math.max(0, newLeft),
      top: Math.max(0, newTop)
    }
  }

  if (isResizing.value) {
    const dx = e.clientX - startPoint.value.x
    const dy = e.clientY - startPoint.value.y
    let { left, top, width, height } = initialBox.value

    switch (resizeDirection.value) {
      case 'se':
        width = Math.max(20, width + dx)
        height = Math.max(20, height + dy)
        break
      case 'sw':
        left = Math.max(0, left + dx)
        width = Math.max(20, width - dx)
        height = Math.max(20, height + dy)
        break
      case 'ne':
        top = Math.max(0, top + dy)
        width = Math.max(20, width + dx)
        height = Math.max(20, height - dy)
        break
      case 'nw':
        left = Math.max(0, left + dx)
        top = Math.max(0, top + dy)
        width = Math.max(20, width - dx)
        height = Math.max(20, height - dy)
        break
    }

    selection.value = {
      left,
      top,
      width,
      height,
      visible: true
    }
  }
}

const handleMouseUp = () => {
  isDrawing.value = false
  isDragging.value = false
  isResizing.value = false
}

const processCurrentImage = async () => {
  if (!currentImage.value) return

  isLoading.value = true
  loadingText.value = '正在去除水印...'

  try {
    await processImage(currentImage.value)
    currentImage.value.processed = true
    displayProcessedImage(currentImage.value)
  } catch (error) {
    console.error('处理失败:', error)
    alert('处理失败: ' + error.message + '\n请确保选区框在图片范围内')
  } finally {
    isLoading.value = false
  }
}

const processImage = (imageData) => {
  return new Promise((resolve, reject) => {
    try {
      const canvas = mainCanvas.value
      if (!canvas) throw new Error('画布不存在')

      const scaleX = imageData.image.width / canvas.width
      const scaleY = imageData.image.height / canvas.height

      const selLeft = selection.value.left
      const selTop = selection.value.top
      const selWidth = selection.value.width
      const selHeight = selection.value.height

      let actualX = Math.floor(selLeft * scaleX)
      let actualY = Math.floor(selTop * scaleY)
      let actualWidth = Math.floor(selWidth * scaleX)
      let actualHeight = Math.floor(selHeight * scaleY)

      actualX = Math.max(0, actualX)
      actualY = Math.max(0, actualY)
      actualWidth = Math.min(imageData.image.width - actualX, actualWidth)
      actualHeight = Math.min(imageData.image.height - actualY, actualHeight)

      if (actualWidth <= 0 || actualHeight <= 0) {
        throw new Error('选区大小无效')
      }

      const tempCanvas = document.createElement('canvas')
      tempCanvas.width = imageData.image.width
      tempCanvas.height = imageData.image.height
      const tempCtx = tempCanvas.getContext('2d')
      tempCtx.drawImage(imageData.image, 0, 0)

      removeWatermark(tempCtx, actualX, actualY, actualWidth, actualHeight)

      imageData.processedDataUrl = tempCanvas.toDataURL(imageData.type, 0.95)

      resolve()
    } catch (error) {
      reject(error)
    }
  })
}

const removeWatermark = (ctx, x, y, width, height) => {
  const imageData = ctx.getImageData(0, 0, ctx.canvas.width, ctx.canvas.height)
  const data = imageData.data
  const imgWidth = ctx.canvas.width
  const imgHeight = ctx.canvas.height

  const borderSize = 10

  for (let py = y; py < y + height; py++) {
    for (let px = x; px < x + width; px++) {
      if (py < 0 || py >= imgHeight || px < 0 || px >= imgWidth) continue

      const pixelIndex = (py * imgWidth + px) * 4
      const avgColor = getSurroundingAverage(data, imgWidth, imgHeight, px, py, borderSize)

      data[pixelIndex] = avgColor.r
      data[pixelIndex + 1] = avgColor.g
      data[pixelIndex + 2] = avgColor.b
    }
  }

  ctx.putImageData(imageData, 0, 0)
}

const getSurroundingAverage = (data, imgWidth, imgHeight, x, y, borderSize) => {
  let r = 0, g = 0, b = 0, count = 0

  for (let dy = -borderSize; dy <= borderSize; dy++) {
    for (let dx = -borderSize; dx <= borderSize; dx++) {
      if (dx === 0 && dy === 0) continue

      const nx = x + dx
      const ny = y + dy

      if (nx < 0 || nx >= imgWidth || ny < 0 || ny >= imgHeight) continue

      const pixelIndex = (ny * imgWidth + nx) * 4
      r += data[pixelIndex]
      g += data[pixelIndex + 1]
      b += data[pixelIndex + 2]
      count++
    }
  }

  if (count === 0) {
    return { r: 255, g: 255, b: 255 }
  }

  return {
    r: Math.floor(r / count),
    g: Math.floor(g / count),
    b: Math.floor(b / count)
  }
}

const downloadCurrentImage = () => {
  if (!currentImage.value || !currentImage.value.processed) return

  const link = document.createElement('a')
  link.download = getProcessedFilename(currentImage.value.name)
  link.href = currentImage.value.processedDataUrl
  link.click()
}

const downloadAllAsZip = async () => {
  const processedImages = images.value.filter(img => img.processed)
  if (processedImages.length === 0) return

  isLoading.value = true
  loadingText.value = '正在打包文件...'

  try {
    const zip = new JSZip()

    processedImages.forEach(image => {
      const base64Data = image.processedDataUrl.split(',')[1]
      zip.file(getProcessedFilename(image.name), base64Data, { base64: true })
    })

    const content = await zip.generateAsync({ type: 'blob' })
    const link = document.createElement('a')
    link.href = URL.createObjectURL(content)
    link.download = 'processed_images.zip'
    link.click()
  } catch (error) {
    console.error('打包失败:', error)
    alert('打包失败，请重试')
  } finally {
    isLoading.value = false
  }
}

const getProcessedFilename = (originalName) => {
  const dotIndex = originalName.lastIndexOf('.')
  if (dotIndex === -1) return originalName + '_processed'
  return originalName.substring(0, dotIndex) + '_processed' + originalName.substring(dotIndex)
}

onMounted(() => {
  document.addEventListener('mousemove', handleMouseMove)
  document.addEventListener('mouseup', handleMouseUp)
})

onUnmounted(() => {
  document.removeEventListener('mousemove', handleMouseMove)
  document.removeEventListener('mouseup', handleMouseUp)
})

watch(images, () => {}, { deep: true })
</script>