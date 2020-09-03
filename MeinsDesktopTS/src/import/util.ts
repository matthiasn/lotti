// from https://gist.github.com/Atinux/fd2bcce63e44a7d3addddc166ce93fb2
export async function asyncForEach(array: any[], callback: Function) {
  for (let index = 0; index < array.length; index++) {
    await callback(array[index], index, array)
  }
}
