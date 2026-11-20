document.getElementById("year").textContent=new Date().getFullYear();
document.getElementById("copyDonationAddress")?.addEventListener("click",async()=>{const address=document.getElementById("donationAddress")?.textContent?.trim();const status=document.getElementById("donationCopyStatus");try{await navigator.clipboard.writeText(address);if(status)status.textContent="تم نسخ عنوان الاستقبال. تأكد من الشبكة قبل التحويل.";}catch{if(status)status.textContent="تعذر النسخ تلقائيًا. اضغط مطولًا على العنوان لنسخه يدويًا.";}});document.getElementById("interest").addEventListener("click",async()=>{const msg="مرحبًا، أرغب بالتواصل مع فريق منصة سند لمعرفة فرص التطوع أو التعاون المؤسسي.";const status=document.getElementById("status");try{await navigator.clipboard.writeText(msg);status.textContent="تم نسخ رسالة الاهتمام. يمكنك لصقها وإرسالها بالطريقة التي تناسبك."}catch{status.textContent=msg}});if("serviceWorker"in navigator&&location.protocol.startsWith("http"))addEventListener("load",()=>navigator.serviceWorker.register("./sw.js").catch(()=>{}));
// Accessibility and public demo interactions
(()=>{let scale=1;document.getElementById('fontUp')?.addEventListener('click',()=>{scale=Math.min(1.3,scale+.1);document.documentElement.style.fontSize=(16*scale)+'px'});document.getElementById('fontDown')?.addEventListener('click',()=>{scale=Math.max(.85,scale-.1);document.documentElement.style.fontSize=(16*scale)+'px'});document.getElementById('contrast')?.addEventListener('click',()=>document.body.classList.toggle('high-contrast'));document.getElementById('theme')?.addEventListener('click',()=>document.body.classList.toggle('dark'));document.getElementById('lang')?.addEventListener('click',()=>{alert('النسخة الإنجليزية قيد الإعداد. English version is planned.');});const search=document.getElementById('siteSearch');search?.addEventListener('input',()=>{const q=search.value.trim().toLowerCase();let n=0;document.querySelectorAll('main section').forEach(s=>{const hit=!q||s.innerText.toLowerCase().includes(q);s.hidden=!hit;if(hit)n++});document.getElementById('searchCount').textContent=q?'الأقسام المطابقة: '+n:''});const aidForm=document.getElementById('publicAid');
if(aidForm){aidForm.addEventListener('submit',async e=>{e.preventDefault();const notice=document.getElementById('aidNotice');const form=new FormData(aidForm);const values={p_full_name:String(form.get('full_name')||'').trim(),p_identity_number:String(form.get('identity_number')||'').trim(),p_phone:String(form.get('phone')||'').trim(),p_region:String(form.get('region')||'').trim(),p_locality:String(form.get('locality')||'').trim(),p_household_size:Number(form.get('household_size')),p_children_count:Number(form.get('children_count')),p_elderly_count:Number(form.get('elderly_count')),p_disability_count:Number(form.get('disability_count')),p_marital_status:String(form.get('marital_status')||'').trim(),p_need_type:String(form.get('need_type')||'').trim(),p_details:String(form.get('details')||'').trim(),p_consent:form.get('consent')==='on'};const submit=aidForm.querySelector('button[type="submit"]');submit.disabled=true;notice.textContent='جارٍ إرسال الطلب وحفظ البيانات الشخصية بصورة مشفرة…';try{const response=await fetch('https://vovpbesmqgvfpjxslzbx.supabase.co/rest/v1/rpc/submit_public_aid_request',{method:'POST',headers:{'apikey':'sb_publishable_1T4fLsk02CYnxnJOFVGhtw_Mh-t9V3j','Authorization':'Bearer sb_publishable_1T4fLsk02CYnxnJOFVGhtw_Mh-t9V3j','Content-Type':'application/json'},body:JSON.stringify(values)});const result=await response.json().catch(()=>({}));if(!response.ok)throw new Error(result.message||result.details||'HTTP '+response.status);const ref=Array.isArray(result)?result[0]?.reference_code:result.reference_code;notice.textContent='تم استلام طلبك بنجاح. رقم المتابعة: '+(ref||'تم التسجيل')+'. احتفظ بهذا الرقم عند التواصل مع سند.';aidForm.reset();}catch(error){console.error('Aid request submission failed:',error);notice.textContent='تعذر إرسال الطلب: '+(error.message||'خطأ اتصال')+'. يرجى المحاولة لاحقًا.';}finally{submit.disabled=false;}});}document.getElementById('volunteerInterest')?.addEventListener('submit',e=>{e.preventDefault();const notice=document.getElementById('volunteerNotice');if(notice)notice.textContent='نموذج التطوع لم يُفعّل بعد.';});})();


// Responsive navigation menu for tablet and mobile
(()=>{
 const header=document.querySelector('body > header');
 if(!header) return;
 const nav=header.querySelector('nav');
 let toggle=header.querySelector('.mobile-menu-toggle');
 if(!nav || !toggle) return;
 nav.id='primary-navigation';
 toggle.setAttribute('aria-controls','primary-navigation');
 const close=()=>{
  header.classList.remove('is-menu-open');
  toggle.setAttribute('aria-expanded','false');
  toggle.innerHTML='<span aria-hidden="true">☰</span><span>القائمة</span>';
 };
 toggle.addEventListener('click',()=>{
  const opening=!header.classList.contains('is-menu-open');
  header.classList.toggle('is-menu-open',opening);
  toggle.setAttribute('aria-expanded',String(opening));
  toggle.innerHTML=opening?'<span aria-hidden="true">✕</span><span>إغلاق</span>':'<span aria-hidden="true">☰</span><span>القائمة</span>';
 });
 header.querySelectorAll('nav a, .outline').forEach(link=>link.addEventListener('click',close));
 document.addEventListener('keydown',event=>{if(event.key==='Escape')close();});
 window.addEventListener('resize',()=>{if(window.innerWidth>820)close();});
})();


/* Public donation ledger: only rows returned by the confirmed-only database function are rendered. */
(async()=>{
 const summary=document.getElementById('donationPublicSummary');
 const list=document.getElementById('donationPublicList');
 if(!summary||!list)return;
 const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const money=(amount,currency)=>new Intl.NumberFormat('ar',{style:'currency',currency:String(currency||'USD').trim(),maximumFractionDigits:2}).format(Number(amount||0));
 try{
  const response=await fetch('https://vovpbesmqgvfpjxslzbx.supabase.co/rest/v1/rpc/list_public_confirmed_donations',{method:'POST',headers:{'apikey':'sb_publishable_1T4fLsk02CYnxnJOFVGhtw_Mh-t9V3j','Authorization':'Bearer sb_publishable_1T4fLsk02CYnxnJOFVGhtw_Mh-t9V3j','Content-Type':'application/json'},body:'{}'});
  const rows=await response.json();
  if(!response.ok)throw new Error(rows.message||'HTTP '+response.status);
  const totals={};
  rows.forEach(row=>{const currency=String(row.currency||'USD').trim();totals[currency]=(totals[currency]||0)+Number(row.amount||0);});
  const currencies=Object.entries(totals);
  summary.innerHTML=currencies.length?currencies.map(([currency,total])=>'<article><h4>إجمالي التبرعات المؤكدة ('+esc(currency)+')</h4><strong>'+esc(money(total,currency))+'</strong><p class="subtle">'+rows.length+' عملية مؤكدة ضمن السجل المعروض</p></article>').join(''):'<article><h4>إجمالي التبرعات المؤكدة</h4><strong>0</strong><p class="subtle">لا توجد تبرعات مؤكدة منشورة حتى الآن.</p></article>';
  if(!rows.length){list.innerHTML='<p class="empty">لا توجد عمليات تبرع مؤكدة للعرض حاليًا. ستظهر هنا بعد مطابقة التحويلات وتأكيد وصولها.</p>';return;}
  list.innerHTML='<table><thead><tr><th>الرقم المرجعي</th><th>الحملة</th><th>المبلغ</th><th>تاريخ التأكيد</th><th>الحالة</th></tr></thead><tbody>'+rows.map(row=>'<tr><td dir="ltr">'+esc(row.public_reference)+'</td><td>'+esc(row.campaign_title)+'</td><td>'+esc(money(row.amount,row.currency))+'</td><td>'+esc(row.confirmed_at?new Date(row.confirmed_at).toLocaleString('ar'): '—')+'</td><td>مؤكد بعد التحقق</td></tr>').join('')+'</tbody></table>';
 }catch(error){console.error('Public donation ledger failed:',error);summary.innerHTML='<article>تعذر تحميل إجمالي التبرعات حاليًا.</article>';list.innerHTML='<p class="subtle">تعذر تحميل سجل التبرعات. يرجى المحاولة لاحقًا.</p>';}
})();
