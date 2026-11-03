export const statuses=['pending','approved','changes'];
export function emptyReview(number,revision) {return {number,revision,status:'pending',notes:'',markers:[],updatedAt:null};}
export function exportReview(bank,scenes,records) {
  return {format:'csgt-animation-review',version:1,bankId:bank.id,sourceSha256:bank.sourceSha256,exportedAt:new Date().toISOString(),records:bank.questions.map(q=>records[q.number]||emptyReview(q.number,scenes[String(q.number)].revision))};
}
export function importReview(payload,bank,scenes) {
  if(payload?.format!=='csgt-animation-review'||payload.version!==1||payload.bankId!==bank.id||payload.sourceSha256!==bank.sourceSha256||!Array.isArray(payload.records)||payload.records.length>115)throw new Error('File duyệt không đúng bộ câu hỏi hoặc phiên bản nguồn.');
  const result={};
  for(const record of payload.records) {
    if(!Number.isInteger(record.number)||record.number<486||record.number>600||Object.hasOwn(result,record.number)||!statuses.includes(record.status)||typeof record.revision!=='string'||typeof record.notes!=='string'||record.notes.length>4000||!Array.isArray(record.markers)||record.markers.length>20)throw new Error('Dữ liệu duyệt không hợp lệ.');
    if(record.markers.some(p=>!Number.isFinite(p.x)||!Number.isFinite(p.y)||p.x<0||p.x>100||p.y<0||p.y>100))throw new Error('Vị trí đánh dấu không hợp lệ.');
    const changed=record.revision!==scenes[String(record.number)].revision;
    result[record.number]={...emptyReview(record.number,scenes[String(record.number)].revision),status:changed?'pending':record.status,notes:record.notes,markers:record.markers.map(p=>({x:p.x,y:p.y})),updatedAt:typeof record.updatedAt==='string'?record.updatedAt:null,previousRevision:changed?record.revision:record.previousRevision||null,previousStatus:changed?record.status:record.previousStatus||null};
  }
  return result;
}
